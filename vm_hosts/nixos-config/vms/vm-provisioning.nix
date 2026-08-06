{
  lib,
  config,
  pkgs,
  nixpkgs,
  NixVirt,
  nixos-generators,
  ...
}: {
  imports = [nixos-generators.nixosModules.all-formats];

  options = {
    vms = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {type = lib.types.str;};
          modules = lib.mkOption {type = lib.types.listOf lib.types.path;};
          diskSize = lib.mkOption {
            type = lib.types.int;
            default = 10 * 1024;
          };
          uuid = lib.mkOption {type = lib.types.str;};
          mem_gb = lib.mkOption {
            type = lib.types.int;
            default = 2;
          };
          devices = lib.mkOption { type = lib.types.attrs; default = {}; };

          # USB dongles to hand to this VM, identified by their *serial number*
          # (see /sys/bus/usb/devices/*/serial or /dev/serial/by-id/).
          #
          # Matching on vendor:product is not enough here — the Sonoff Zigbee V2
          # and the Zooz Z-Wave stick are both 1a86:55d4 — and the bus/device
          # numbers the old hand-written XMLs used are reassigned on every boot.
          # Serials are stable, so we resolve them to an address at start time.
          usbSerials = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
        };
      });
      default = [];
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.lists.allUnique (map (vm: vm.uuid) config.vms);
        message = "Duplicated UUIDs for VMs";
      }
    ];

    environment.systemPackages = [pkgs.virtiofsd];

    systemd.services = builtins.listToAttrs (map (vm: let
        iso_img = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [{virtualisation.diskSize = vm.diskSize;}] ++ vm.modules;
          format = "qcow";
        };
      in {
        name = "vm-prep-${vm.name}";
        value = {
          description = "prep for ${vm.name} vm";
          # network.target only means "networkd has started", not that we have
          # an address; qemu needs a real IPv4 address to bring up SPICE. Wait
          # for network-online.target (now gated on a routable v4 addr, see
          # alfa.nix) and for libvirtd to be accepting connections.
          after = ["network-online.target" "libvirtd.service"];
          wants = ["network-online.target"];
          requires = ["libvirtd.service"];
          before = ["nixvirt.service"];
          restartTriggers = ["${iso_img.outPath}/nixos.qcow2"];
          script = ''
            mkdir -p /var/lib/libvirt/images
            rm -f /var/lib/libvirt/images/${vm.name}.qcow2
            cp ${iso_img.outPath}/nixos.qcow2 /var/lib/libvirt/images/${vm.name}.qcow2
            chmod ug+rw /var/lib/libvirt/images/${vm.name}.qcow2
            /run/current-system/sw/bin/virsh -c qemu:///system destroy ${vm.name} || true

            # Backstop for transient start failures the ordering above cannot
            # cover (a slow switch delaying DHCP past wait-online's timeout,
            # libvirtd still settling, storage not ready). Without this a
            # single failure left the VM shut off until someone noticed.
            started=false
            for attempt in $(seq 1 10); do
              if /run/current-system/sw/bin/virsh -c qemu:///system start ${vm.name}; then
                started=true
                break
              fi
              echo "start attempt $attempt for ${vm.name} failed; retrying in 15s"
              sleep 15
            done
            if [ "$started" != true ]; then
              echo "ERROR: ${vm.name} did not start after 10 attempts"
              exit 1
            fi
          ''
          + lib.concatMapStrings (serial: ''

            # --- USB passthrough: serial ${serial} ---
            # The domain was just destroyed and recreated, so there is nothing
            # attached yet and this cannot double-attach.
            devpath=""
            for d in /sys/bus/usb/devices/*/; do
              if [ -r "$d/serial" ] && [ "$(cat "$d/serial")" = "${serial}" ]; then
                devpath="$d"
                break
              fi
            done

            if [ -z "$devpath" ]; then
              echo "WARNING: no USB device with serial ${serial} present; skipping"
            else
              vid=$(cat "$devpath/idVendor")
              pid=$(cat "$devpath/idProduct")
              busnum=$(cat "$devpath/busnum")
              devnum=$(cat "$devpath/devnum")
              echo "Attaching USB $vid:$pid (serial ${serial}) at bus $busnum device $devnum to ${vm.name}"

              printf '<hostdev mode="subsystem" type="usb" managed="yes"><source><vendor id="0x%s"/><product id="0x%s"/><address type="usb" bus="%d" device="%d"/></source></hostdev>' \
                "$vid" "$pid" "$busnum" "$devnum" \
                > /run/usb-${vm.name}-${serial}.xml

              # qemu may not have finished coming up the instant virsh start
              # returns, so give the attach a few tries before giving up.
              for attempt in 1 2 3 4 5 6 7 8 9 10; do
                if /run/current-system/sw/bin/virsh -c qemu:///system \
                     attach-device ${vm.name} --file /run/usb-${vm.name}-${serial}.xml --live; then
                  break
                fi
                echo "attach attempt $attempt failed; retrying in 3s"
                sleep 3
              done
            fi
          '') vm.usbSerials;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          wantedBy = ["multi-user.target"];
        };
      })
      config.vms);

    virtualisation.libvirt.connections."qemu:///system".domains =
      map (vm: {
        active = true;
        definition =
        let linux = NixVirt.lib.domain.templates.linux {
                                name = vm.name;
                                uuid = vm.uuid;
                                memory = {
                                  count = vm.mem_gb;
                                  unit = "GiB";
                                };
                              }; in
        NixVirt.lib.domain.writeXML (
        linux //
           {
            memoryBacking = {
              source = {type = "memfd";};
              access = {mode = "shared";};
            };
            vcpu = {
             placement = "static";
             count = 4;
            };
            cpu = {
              mode = "host-passthrough";
              topology = {
                sockets = 1;
                cores = 4;
                threads = 1;
              };
            };
            devices = linux.devices // vm.devices // {
              interface = [
                {
                  type = "bridge";
                  source = {bridge = "br0";};
                }
              ];
              disk =  [
                {
                  type = "file";
                  device = "disk";
                  source = {file = "/var/lib/libvirt/images/${vm.name}.qcow2";};
                  target = {
                    dev = "vda";
                    bus = "virtio";
                  };
                  driver = {
                    name = "qemu";
                    type = "qcow2";
                  };
                }
              ];
              filesystem = [
                {
                  driver = {type = "virtiofs";};
                  source = {dir = "/orbweaver/v/${vm.name}";};
                  target = {dir = "persist";};
                  binary = {path = "/run/current-system/sw/bin/virtiofsd";};
                }
              ];
              controller = {
                type = "virtio-serial";
                index = 0;
              };
              channel = [
                {
                  type = "spicevmc";
                  target = {
                    type = "virtio";
                    name = "com.redhat.spice.0";
                  };
                  address = {
                    type = "virtio-serial";
                    controller = 0;
                    bus = 0;
                    port = 1;
                  };
                }
              ];
              graphics = {
                type = "spice";
                autoport = true;
                listen = {
                  type = "address";
                };
              };
              video = {
                model = {
                  type = "qxl";
                  heads = 1;
                  ram = 65536;
                  vram = 65536;
                  primary = true;
                };
              };
              console = {
                type = "pty";
                target = {
                  type = "serial";
                  port = 0;
                };
              };
            };
          }
        );
      })
      config.vms;
  };
}
