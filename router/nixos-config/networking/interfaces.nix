{
  config,
  lib,
  pkgs,
  ...
}: {
  systemd.network.wait-online.enable = true;
  systemd.network.wait-online.anyInterface = true;

  systemd.network.links = {
    "10-en0-WAN" = {
      matchConfig.Property = "ID_NET_NAME_PATH=enp6s0";
      linkConfig.Name = "wan0";
    };

    "10-lan1" = {
      matchConfig.Property = "ID_NET_NAME_PATH=enp10s0";
      linkConfig.Name = "lan1";
    };

    "10-lan2" = {
      matchConfig.Property = "ID_NET_NAME_PATH=enp5s0";
      linkConfig.Name = "lan2";
    };

    "10-lan3" = {
      matchConfig.Property = "ID_NET_NAME_PATH=enp9s0";
      linkConfig.Name = "lan3";
    };
    "10-lan4" = {
      matchConfig.Property = "ID_NET_NAME_PATH=enp4s0";
      linkConfig.Name = "lan4";
    };

    "10-lan5" = {
      matchConfig.Property = "ID_NET_NAME_PATH=enp8s0";
      linkConfig.Name = "lan5";
    };

    "10-lan6" = {
      matchConfig.Property = "ID_NET_NAME_PATH=enp3s0";
      linkConfig.Name = "lan6";
    };
    "10-lan7" = {
      matchConfig.Property = "ID_NET_NAME_PATH=enp7s0";
      linkConfig.Name = "lan7";
    };
    "10-mgmt0" = {
      matchConfig.Property = "ID_NET_NAME_PATH=enp13s0";
      linkConfig.Name = "mgmt0";
    };
  };
  systemd.network.netdevs = {
    "10-lanBond0" = {
      netdevConfig.Name = "lanBond0";
      netdevConfig.Kind = "bond";
      bondConfig.Mode = "802.3ad";
      bondConfig.TransmitHashPolicy = "layer3+4";
    };
  };

  systemd.network.networks =
    lib.listToAttrs (
      map (interface: {
        name = "lan${toString interface}";
        value = {
          matchConfig.Name = "lan${toString interface}";
          networkConfig = {
            DHCP = "no";
            Bond = "lanBond0";
          };
        };
      })
      [1 2 3 4 5 6 7]
    )
    // lib.listToAttrs (
      map (vlan: {
        name = "20-${toString vlan.name}";
        value = {
          matchConfig.Name = vlan.name;
          address = ["10.0.${toString vlan.id}.1/24"];
          networkConfig = {
            DHCP = "no";
          };
        };
      })
      config.vlans.vlans
    )
    // {
      "10-lanBond0-LAN" = {
        matchConfig.Name = "lanBond0";
        address = ["10.0.0.1/24"];
        dns = ["8.8.8.8"];
        networkConfig = {
          DHCP = "no";
        };
        vlan = map (vlan: vlan.name) config.vlans.vlans;
      };
      "10-wan0-WAN" = {
        matchConfig.Name = "wan0";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
          IPForward = "yes"; # This sets a kernel parameter; not specific to this interface
          IPMasquerade = "yes";
        };
      };
      "mgmt0" = {
        matchConfig.Name = "mgmt0";
        address = ["10.99.99.1/24"];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = true;
        };
      };
    };
}
