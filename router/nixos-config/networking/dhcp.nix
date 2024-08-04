{
  config,
  lib,
  pkgs,
  ...
}: let
  subnet4 =
    map (vlan: {
      subnet = vlan.subnet;
      id = vlan.id;
      pools = [{pool = "10.0.${toString vlan.id}.100 - 10.0.${toString vlan.id}.200";}];
      option-data = [
        {
          name = "routers";
          data = "10.0.${toString vlan.id}.1";
        }
        {
          name = "domain-name-servers";
          data = "";
        }
        {
          name = "domain-search";
          data = "43mar.io";
        }
      ];
    })
    config.vlans.vlans
    ++ [
      {
        id = 1;
        subnet = "10.0.0.0/24";
        pools = [{pool = "10.0.0.100 - 10.0.0.200";}];
        option-data = [
          {
            name = "routers";
            data = "10.0.0.1";
          }

          {
            name = "domain-name-servers";
            data = "10.0.0.1";
          }
          {
            name = "domain-search";
            data = "43mar.io";
          }

        ];
      }
    ];
in {
  services.postgresql.ensureUsers = [{
    name = "kea";
    ensureDBOwnership = true;
  }];
  services.postgresql.ensureDatabases = ["kea"];
  systemd.services.kea-dhcp4-server.path = [ pkgs.postgresql ];
  services.kea.dhcp4.enable = true;
  services.kea.dhcp4.settings = {
    interfaces-config = {
      interfaces = map (vlan: vlan.interface) config.vlans.vlans ++ ["lanBond0"];
    };

    lease-database = {
      type = "postgresql";
      name = "kea";
      host = "127.0.0.1";
      user = "kea";
      password = "kea"; #MANUALLY added: sudo -u kea psql; psql=> \password
    };
    subnet4 = subnet4;
    dhcp-ddns = {
      enable-updates = true;
    };
    ddns-update-on-renew = true;
    ddns-qualifying-suffix = "43mar.io";
  };
  systemd.services.kea-dhcp4-server.after = [ "kea-dhcp-ddns-server.service" ];
  services.kea.dhcp-ddns = {
    enable = true;
    extraArgs = ["-d"];
    settings = {
      dns-server-timeout = 100;
      forward-ddns = {
        ddns-domains = [
         {
             name = "43mar.io.";
             key-name = "";
             dns-servers = [{
               ip-address = "127.0.0.1";
             port = 53000;
             }];
          }
        ];
      };
      ip-address = "127.0.0.1";
      ncr-format = "JSON";
      ncr-protocol = "UDP";
      port = 53001;
      reverse-ddns = {
        ddns-domains = [];
      };
      tsig-keys = [];
    };
  };
}
