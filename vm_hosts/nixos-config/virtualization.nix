{
  lib,
  config,
  pkgs,
  NixVirt,
  ...
}: {
  imports = [
    ./vms/vm-provisioning.nix
  ];
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [
          (pkgs.OVMF.override {
            secureBoot = true;
            tpmSupport = true;
          })
          .fd
        ];
      };
    };
  };
  system.activationScripts.makeDefaultPool = lib.stringAfter ["var"] ''
    mkdir -p /var/lib/libvirt/images
  '';
  virtualisation.libvirt = {
    enable = true;
    connections."qemu:///system" = {
      pools = [
        {
          active = true;
          definition = NixVirt.lib.pool.writeXML {
            name = "default";
            type = "dir";
            uuid = "5a20ff16-b3f0-472e-886f-9158afe12b6c";
            target = {
              path = "/var/lib/libvirt/images";
              permissions = {
                mode = "0755";
                owner = "1000";
                group = "100";
              };
            };
          };
        }
      ];
      networks = [
        {
          active = true;
          definition = NixVirt.lib.network.writeXML {
            name = "default";
            uuid = "35274393-898d-4e52-98ae-dcc451949088";
            bridge = {name = "br0";};
            forward = {mode = "bridge";};
          };
        }
      ];
    };
  };
}
