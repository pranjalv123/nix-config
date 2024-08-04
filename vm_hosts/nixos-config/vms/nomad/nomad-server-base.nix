{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [../vm-base.nix ../base/vault-agent.nix ../consul/consul-client-base.nix];

  options = {
    nomad.index = lib.mkOption {type = lib.types.str; };
  };

  config = {
    cert.serviceToReload = ["nomad" "consul"];
    cert.altNames = "server.global.nomad";

    networking.hostName = "nomad-server-${config.nomad.index}";

    users.groups.nomad = {};
    users.users.nomad = {
      isSystemUser = true;
      group = "nomad";
    };

    users.groups.consul = {};
    users.users.consul = {
      isSystemUser = true;
      group = "consul";
    };


    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = [pkgs.nomad pkgs.consul];


    services.nomad = {
      enable = true;
      dropPrivileges = false;
      extraSettingsPaths = ["/persist/nomad-config"];
      settings = {
        datacenter = "dc1";
        data_dir = "/persist/nomad";
        telemetry = {
         collection_interval = "5s";
         publish_allocation_metrics = true;
         publish_node_metrics = true;
         prometheus_metrics = true;
        };
        server = {
          enabled = true;
          bootstrap_expect = 1;
        };
        # Require TLS
        tls  = {
          http = true;
          rpc  = true;

          ca_file   = "/persist/vault-agent/ca.crt";
          cert_file = "/persist/vault-agent/cert.pem";
          key_file  = "/persist/vault-agent/key.pem";

          verify_server_hostname = true;
          verify_https_client    = false;
        };
      };
    };

    systemd.services.nomad = {
      wants = ["network-online.target" "mount_fs.service"];
      after = ["network-online.target" "mount_fs.service"];
      serviceConfig = {
        restartSec = 10;
      };
    };
  };
}
