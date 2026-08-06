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
      diskSize = 20 * 1024;
    }
    {
      name = "nomad-client-1";
      mem_gb = 24;
      modules = [./vms/nomad/nomad-client-1.nix];
      uuid = "521221b9-1448-4e0b-b3e8-4f88c204afd5";
      diskSize = 20 * 1024;
      # Attached at VM start by serial, which survives reboots — the bus/device
      # numbers these used to be pinned to do not. Replaces hand-running
      # `virsh attach-device nomad-client-1 --file ~/sonoff-e-usb.xml` after
      # every restart.
      usbSerials = [
        "20240123213326" # ITEAD Sonoff Zigbee 3.0 Dongle Plus V2 -> zigbee2mqtt
        "533D004242"     # Zooz 800 Z-Wave Stick                  -> zwavejs
      ];
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
  services.samba = {
    enable = true;
    securityType = "user";
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "smbnix";
        "netbios name" = "smbnix";
        "security" = "user";
        "hosts allow" = "10.0.0.0/8 192.168.1.0/16 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
    };

    shares = {
      private = {
        path = "/orbweaver";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "pranjal";
        "force group" = "users";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

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
        # network-online.target used to be satisfied by IPv6LL alone, so on a
        # cold boot where the switch came up slowly it fired ~70s before the
        # DHCPv4 lease landed. qemu's SPICE calls getaddrinfo() with
        # AI_ADDRCONFIG, which refuses to return IPv4 results while the host
        # has no non-loopback IPv4 address -- so binding 127.0.0.1:5900 failed
        # with "Address family for hostname not supported" and every VM failed
        # to start. Hold the target until mgmt actually has a routable v4 addr.
        linkConfig = {
          RequiredForOnline = "routable";
          RequiredFamilyForOnline = "ipv4";
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
