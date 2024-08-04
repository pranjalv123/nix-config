{
  config,
  lib,
  pkgs,
  NixVirt,
  ...
}: {
  imports = [
    ./alfa-hardware-configuration.nix
  ];

  vms = [
    {
      name = "vault";
      mem_gb = 4;
      modules = [./vms/vault/vault.nix];
      uuid = "9a3b3fa6-c243-4f32-8505-492098394f45";
      diskSize = 10 * 1024;
    }
    {
      name = "consul-server-1";
      mem_gb = 2;
      modules = [./vms/consul/consul-server-1.nix];
      uuid = "b35aab7f-e6b2-460a-b6ca-d8f5bdffa9a9";
      diskSize = 10 * 1024;
    }
    {
      name = "nomad-server-1";
      mem_gb = 2;
      modules = [./vms/nomad/nomad-server-1.nix];
      uuid = "0c79db1a-0501-406b-a8e4-4a5e978f7d65";
      diskSize = 10 * 1024;
    }
    {
      name = "nomad-client-1";
      mem_gb = 24;
      modules = [./vms/nomad/nomad-client-1.nix];
      uuid = "521221b9-1448-4e0b-b3e8-4f88c204afd5";
      diskSize = 10 * 1024;
      devices = {
        hostdev = [
          {
            type = "usb";
            mode = "subsystem";
            source = {
              vendor = {id = "0x1a86";};
              product = {id = "0x55d4";};
            };
          }
          {
            type = "usb";
            mode = "subsystem";
            source = {
              vendor = {id = "0x10c4";};
              product = {id = "0xea60";};
            };
          }
        ];
      };
    }
  ];

  networking.hostName = "alfa"; # Define your hostname
  #hardware.broadcom.enable = true;

  services.openiscsi = {
    enable = true;
    name = "iqn.1994-05.com.redhat:alfa";
  };
  # set up ZFS
  environment.systemPackages = [pkgs.targetcli pkgs.zfs];
  boot.supportedFilesystems = ["zfs"];
  boot.zfs.forceImportRoot = false;
  networking.hostId = "b7cbc15f";

  boot.zfs.extraPools = ["orbweaver"];

  virtualisation.libvirt.connections."qemu:///system".pools = [
    {
      active = true;
      definition = NixVirt.lib.pool.writeXML {
        name = "orbweaver";
        type = "dir";
        uuid = "385a7c0e-a82c-4079-aeb0-9249ee8fa365";
        target = {
          path = "/orbweaver/v";
        };
      };
    }
  ];
  networking.networkmanager.enable = false;
  networking.useDHCP = false;

  systemd.network.enable = true;

  systemd.network = {
    links = {
      "10-mgmt" = {
        matchConfig.Property = "ID_NET_NAME_PATH=enp9s0";
        linkConfig.Name = "mgmt";
      };

      "10-vmlink" = {
        matchConfig.Property = "ID_NET_NAME_PATH=enp4s0";
        linkConfig.Name = "vmlink";
      };
    };
    netdevs = {
      "20-br0" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br0";
        };
      };
    };
    networks = {
      "30-mgmt" = {
        matchConfig.Name = "mgmt";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
        };
      };
      "30-vmlink" = {
        matchConfig.Name = "vmlink";
        networkConfig.Bridge = "br0";
        linkConfig.RequiredForOnline = "enslaved";
      };
      "40-br0" = {
        matchConfig.Name = "br0";
        bridgeConfig = {};
        networkConfig.LinkLocalAddressing = "no";
        linkConfig = {
          # or "routable" with IP addresses configured
          RequiredForOnline = "carrier";
        };
      };
    };
  };
}
