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

  config = let
    virsh = "/run/current-system/sw/bin/virsh -c qemu:///system";
    usbVms = builtins.filter (vm: vm.usbSerials != []) config.vms;

    # Reconciles the VM's USB passthrough against what is actually plugged in.
    #
    # A plain "attach at start" is not enough: the dongles re-enumerate (a
    # disconnect/reconnect moves the Sonoff from bus 1 device 3 to device 4),
    # which silently strips the device from the guest, and a VM restarted by
    # anything other than vm-prep comes up with no hostdevs at all. Both
    # happened. So instead of attaching blindly, diff desired against attached
    # and fix the difference. Safe to run repeatedly.
    reconcileScript = vm:
      pkgs.writeShellScript "vm-usb-reconcile-${vm.name}" ''
        set -u
        export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.gnused]}:$PATH
        VM=${vm.name}
        SERIALS="${lib.concatStringsSep " " vm.usbSerials}"

        # Nothing to reconcile unless the domain is actually running.
        if ! ${virsh} domstate "$VM" 2>/dev/null | grep -q running; then
          exit 0
        fi

        DESIRED=$(mktemp)
        ATTACHED=$(mktemp)
        trap 'rm -f "$DESIRED" "$ATTACHED"' EXIT

        # Desired: "vid pid bus dev serial" for each configured dongle that is
        # currently present on the host. Serial is the stable identity; bus and
        # device are just where it happens to live right now. These go through
        # files rather than shell string accumulation -- building a multi-line
        # variable inside a Nix indented string smuggles the surrounding
        # indentation into every line after the first, which silently broke the
        # comparisons below.
        for serial in $SERIALS; do
          for d in /sys/bus/usb/devices/*/; do
            [ -r "$d/serial" ] || continue
            [ "$(cat "$d/serial" 2>/dev/null)" = "$serial" ] || continue
            printf '%s %s %s %s %s\n' \
              "$(cat "$d/idVendor")" "$(cat "$d/idProduct")" \
              "$(cat "$d/busnum")"   "$(cat "$d/devnum")" "$serial" >> "$DESIRED"
            break
          done
        done

        # Attached: one "vid pid bus dev" line per <hostdev> on the domain. The
        # guest-side <address type='usb' ... port=.../> has no device= attribute,
        # so matching on device= picks out the host source address only.
        ${virsh} dumpxml "$VM" 2>/dev/null | sed "s/'/\"/g" | awk '
          /<hostdev/            { inhd=1; vid=""; pid=""; bus=""; dev="" }
          inhd && /<vendor id=/  { if (match($0,/0x[0-9a-fA-F]+/)) vid=substr($0,RSTART+2,RLENGTH-2) }
          inhd && /<product id=/ { if (match($0,/0x[0-9a-fA-F]+/)) pid=substr($0,RSTART+2,RLENGTH-2) }
          inhd && /<address bus=/ && /device=/ {
            if (match($0,/bus="[0-9]+"/))    bus=substr($0,RSTART+5,RLENGTH-6)
            if (match($0,/device="[0-9]+"/)) dev=substr($0,RSTART+8,RLENGTH-9)
          }
          /<\/hostdev>/ { if (inhd && bus != "" && dev != "") print vid" "pid" "bus" "dev; inhd=0 }
        ' > "$ATTACHED"

        mkxml() { # vid pid bus dev
          printf %s "<hostdev mode=\"subsystem\" type=\"usb\" managed=\"yes\"><source><vendor id=\"0x$1\"/><product id=\"0x$2\"/><address bus=\"$3\" device=\"$4\"/></source></hostdev>"
        }

        # Detach whatever is attached but no longer desired -- typically a
        # hostdev pointing at a bus/device that ceased to exist when the dongle
        # re-enumerated. Leaving it there blocks the re-attach.
        while read -r vid pid bus dev; do
          [ -n "$bus" ] || continue
          if ! grep -q "^$vid $pid $bus $dev " "$DESIRED"; then
            echo "detaching stale hostdev $vid:$pid at bus $bus device $dev from $VM"
            mkxml "$vid" "$pid" "$bus" "$dev" > /run/vm-usb-${vm.name}-detach.xml
            ${virsh} detach-device "$VM" --file /run/vm-usb-${vm.name}-detach.xml --live || true
          fi
        done < "$ATTACHED"

        # Attach whatever is desired but not yet present.
        while read -r vid pid bus dev serial; do
          [ -n "$bus" ] || continue
          if grep -q "^$vid $pid $bus $dev$" "$ATTACHED"; then
            continue
          fi
          echo "attaching USB $vid:$pid (serial $serial) at bus $bus device $dev to $VM"
          mkxml "$vid" "$pid" "$bus" "$dev" > /run/vm-usb-${vm.name}-attach.xml
          for attempt in 1 2 3 4 5; do
            ${virsh} attach-device "$VM" --file /run/vm-usb-${vm.name}-attach.xml --live && break
            echo "attach attempt $attempt failed; retrying in 3s"
            sleep 3
          done
        done < "$DESIRED"
      '';
  in {
    assertions = [
      {
        assertion = lib.lists.allUnique (map (vm: vm.uuid) config.vms);
        message = "Duplicated UUIDs for VMs";
      }
    ];

    environment.systemPackages = [pkgs.virtiofsd];

    # Re-attach within seconds of a dongle being replugged or re-enumerating,
    # rather than waiting for the timer (or for someone to notice the lights).
    services.udev.extraRules = lib.concatMapStrings (vm:
      lib.concatMapStrings (serial: ''
        ACTION=="add", SUBSYSTEM=="usb", ATTR{serial}=="${serial}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="vm-usb-${vm.name}.service"
      '')
      vm.usbSerials)
    usbVms;

    # Catch-all for the cases udev cannot see: a VM restarted by nixvirt or by
    # hand comes up with no hostdevs, and no USB event ever fires.
    systemd.timers = builtins.listToAttrs (map (vm: {
        name = "vm-usb-${vm.name}";
        value = {
          description = "periodic USB passthrough reconcile for ${vm.name}";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "1min";
            AccuracySec = "10s";
          };
        };
      })
      usbVms);

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
          # nixvirt restarts the domain whenever its definition changes, but it
          # does that on its own -- bypassing this unit, so the VM came back
          # with no USB passed through and a half-restored Nomad client. PartOf
          # propagates that restart here first, keeping every VM restart on the
          # one path that recreates the disk and reconciles USB.
          partOf = ["nixvirt.service"];
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
          + lib.optionalString (vm.usbSerials != []) ''

            ${reconcileScript vm}
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          wantedBy = ["multi-user.target"];
        };
      })
      config.vms)
    // builtins.listToAttrs (map (vm: {
        name = "vm-usb-${vm.name}";
        value = {
          description = "reconcile USB passthrough for ${vm.name}";
          after = ["libvirtd.service"];
          # Deliberately not RemainAfterExit: this has to be re-runnable, both
          # from the timer and from udev on every replug.
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${reconcileScript vm}";
          };
        };
      })
      usbVms);

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
              # Listen on a unix socket rather than TCP. With listen type
              # "address" libvirt fills in 127.0.0.1, and qemu resolves that
              # through getaddrinfo() with AI_ADDRCONFIG -- which returns no
              # IPv4 results while the host has no non-loopback IPv4 address.
              # On a cold boot where DHCP was slow that made SPICE fail to bind
              # a *loopback* literal, and every VM refused to start. A unix
              # socket never touches getaddrinfo, so VM startup no longer
              # depends on the external network at all. virt-manager and
              # `virsh domdisplay` still work locally / over SSH.
              graphics = {
                type = "spice";
                autoport = false;
                listen = {
                  type = "socket";
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
