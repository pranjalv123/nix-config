{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  vlans = [
    {
      name = "vlan-admin";
      id = 10;
    }
    {
      name = "vlan-mgmt";
      id = 20;
    }
    {
      name = "vlan-iot";
      id = 30;
    }
    {
      name = "vlan-guest";
      id = 40;
    }
    {
      name = "vlan-server";
      id = 50;
    }
  ];
in {
  vlans.vlans =
    map (vlan: {
      inherit (vlan) name id;
      subnet = "10.0.${toString vlan.id}.0/24";
      interface = "${toString vlan.name}";
    })
    vlans;

  systemd.network.netdevs = lib.mkMerge (
    map (vlan: {
      "01-${vlan.name}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = vlan.name;
        };
        vlanConfig = {
          Id = vlan.id;
        };
      };
    })
    vlans
  );
}
