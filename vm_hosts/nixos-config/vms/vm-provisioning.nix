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
          after = ["network.target"];
          before = ["nixvirt.service"];
          restartTriggers = ["${iso_img.outPath}/nixos.qcow2"];
          script = ''
            mkdir -p /var/lib/libvirt/images
            rm -f /var/lib/libvirt/images/${vm.name}.qcow2
            cp ${iso_img.outPath}/nixos.qcow2 /var/lib/libvirt/images/${vm.name}.qcow2
            chmod ug+rw /var/lib/libvirt/images/${vm.name}.qcow2
            /run/current-system/sw/bin/virsh -c qemu:///system destroy ${vm.name} || true
            /run/current-system/sw/bin/virsh -c qemu:///system start ${vm.name}
          '';
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
