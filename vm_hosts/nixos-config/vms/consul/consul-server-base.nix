{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [../vm-base.nix ../base/vault-agent.nix];

  options = {
    consul.index = lib.mkOption {type = lib.types.str; };
  };

  config = {
    cert.serviceToReload =["consul"];
    cert.altNames = "server.dc1.consul,server.dc1.43mar.io";

    networking.hostName = "consul-server-${config.consul.index}";

    users.groups.consul = {};
    users.users.consul = {
      isSystemUser = true;
      group = "consul";
    };

    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = [pkgs.consul];

    services.consul = {
      webUi = true;
      enable = true;
      extraConfig = {
        datacenter = "dc1";
        data_dir   = "/persist/consul";
        ports = {
          grpc_tls = 8503;
        };
        connect = {
          enabled = true;
        };
        domain = "43mar.io";
        verify_incoming = true;
        verify_outgoing = true;
        verify_server_hostname = true;

        auto_encrypt = {
          allow_tls = true;
        };

        tls = {
          defaults = {
              ca_file   = "/persist/vault-agent/ca.crt";
              cert_file = "/persist/vault-agent/cert.pem";
              key_file  = "/persist/vault-agent/key.pem";

              verify_incoming = true;
              verify_outgoing = true;
          };
          internal_rpc = {
            verify_server_hostname = true;
          };
        };

        server = true;
        bootstrap_expect = 1;
        client_addr = "0.0.0.0";

        addresses = {
          grpc = "127.0.0.1";
        };

      };
    };

    systemd.services.consul = {
      wants = ["network-online.target" "mount_fs.service"];
      after = ["network-online.target" "mount_fs.service"];
      serviceConfig = {
        restartSec = 10;
        Type = "notify";
      };
      startLimitBurst = lib.mkForce  10;
    };
  };
}
