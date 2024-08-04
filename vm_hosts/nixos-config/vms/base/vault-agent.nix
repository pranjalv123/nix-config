{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  options = {
    cert.altNames = lib.mkOption {
      type = lib.types.separatedString ",";
      default = "";
    };
    cert.serviceToReload = lib.mkOption {type = lib.types.listOf lib.types.str;};
  };

  config = {
    environment.systemPackages = with pkgs; [vault];
    users.users.vault-agent = {
      isSystemUser = true;
      group = "vault-agent";
    };
    users.groups.vault-agent = {};

    security.sudo.extraRules = [
      {
        commands = [
          { command = "/run/current-system/sw/bin/pkill -SIGHUP *"; options = ["NOPASSWD"];}
        ];
        users = ["vault-agent"];
        runAs = "root";
      }
    ];

    services.vault-agent.instances.vault-agent = {
      enable = true;
      group = "vault-agent";
      user = "vault-agent";
      settings = {
        vault.address = "https://vault.43mar.io:8200";
        auto_auth = {
          method = [
            {
              type = "approle";
              config = {
                role_id_file_path = "/persist/vault-agent/role_id";
                secret_id_file_path = "/persist/vault-agent/secret_id";
                remove_secret_id_file_after_reading = false;
              };
            }
          ];

          sinks = [
            {
              sink = {
                type = "file";
                config = {
                  path = "/persist/vault-agent/token";
                };
              };
            }
          ];
        };
        template = [
          {
            contents = ''{{with secret "pki_int/issue/pki-${config.networking.hostName}" "format=pem_bundle" "common_name=${config.networking.hostName}.43mar.io" "alt_names=${config.cert.altNames}"}}{{.Data.certificate}}{{ end }}'';
            destination = "/persist/vault-agent/cert.pem";
          }
          {
            contents = ''{{with secret "pki_int/issue/pki-${config.networking.hostName}" "format=pem_bundle" "common_name=${config.networking.hostName}.43mar.io" "alt_names=${config.cert.altNames}"}}{{.Data.private_key}}{{ end }}'';
            destination = "/persist/vault-agent/key.pem";
            exec = {
              command = lib.concatStrings( map (service: "/run/wrappers/bin/sudo /run/current-system/sw/bin/pkill -SIGHUP ${service} || true; ") config.cert.serviceToReload  );
            };
          }
          {
            contents = ''{{with secret "pki_int/issue/pki-${config.networking.hostName}" "format=pem_bundle" "common_name=${config.networking.hostName}.43mar.io" "alt_names=${config.cert.altNames}"}}{{.Data.issuing_ca}}{{ end }}'';
            destination = "/persist/vault-agent/ca.crt";
          }
        ];
      };
    };

    systemd.services.vault = {
      wants = ["network-online.target" "mount_fs.service"];
      after = ["network-online.target" "mount_fs.service"];
      serviceConfig = {
        restartSec = 10;
      };
      startLimitBurst = lib.mkForce 10;
    };
  };
}
