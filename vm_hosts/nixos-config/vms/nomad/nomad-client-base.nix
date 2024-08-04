{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: let
 usb-plugin = pkgs.callPackage ./plugins/nomad-usb.nix {  };
 in {
  imports = [../vm-base.nix ../base/vault-agent.nix ../consul/consul-client-base.nix];

  options = {
    nomad.index = lib.mkOption {type = lib.types.str; };
  };

  config = {
    cert.serviceToReload = ["nomad" "consul"];
    cert.altNames = "client.global.nomad";

    networking.hostName = "nomad-client-${config.nomad.index}";

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

    environment.systemPackages = [pkgs.nomad pkgs.consul pkgs.libusb1 ];

    services.openiscsi = {
      enable = true;
      name = "iqn.1994-05.com.redhat:nomad-client-${config.nomad.index}";
    };

    services.nomad = {
      enable = true;
      dropPrivileges = false;

      extraPackages = [ pkgs.usbutils pkgs.cni-plugins ];
      extraSettingsPlugins = [ usb-plugin ];
      settings = {
        datacenter = "dc1";
        data_dir = "/persist/nomad";
        telemetry = {
         collection_interval = "5s";
         publish_allocation_metrics = true;
         publish_node_metrics = true;
         prometheus_metrics = true;
        };
        client = {
          enabled = true;
          cni_path = "${pkgs.cni-plugins}/bin";

          host_volume = {
            "bin" = {
              path      = "/run/current-system/sw/bin";
              read_only = true;
            };
            "store" = {
              path      = "/nix/store";
              read_only = true;
            };
          };
        };
        plugin = [{
          docker = [{
            config = {
                      allow_caps = [
                        "SYS_ADMIN" "SYS_CHROOT" "SYS_PTRACE" "DAC_READ_SEARCH"
                        "NET_RAW" "NET_ADMIN" "CHOWN" "DAC_OVERRIDE" "FSETID" "FOWNER" "MKNOD" "NET_RAW" "SETGID"
                        "SETUID" "SETFCAP" "SETPCAP" "NET_BIND_SERVICE" "SYS_CHROOT" "KILL" "AUDIT_WRITE" "NET_ADMIN"
                      ];
                      allow_privileged = true;
                      volumes = {
                        enabled = true;
                      };
                    };
          }];
          }
          {
          usb = [{

            config = {
                        enabled = true;
                        included_vendor_ids = [4292 6790];
                        excluded_vendor_ids = [];

                        included_product_ids = [60000 21972];
                        excluded_product_ids = [];

                        fingerprint_period = "1m";
                      };
          }];
          }
        ];

        
        
        # Require TLS
        tls = {
          http = true;
          rpc  = true;
        
          ca_file   = "/persist/vault-agent/ca.crt";
          cert_file = "/persist/vault-agent/cert.pem";
          key_file  = "/persist/vault-agent/key.pem";
        
          verify_server_hostname = true;
          verify_https_client    = false;
        };

        vault = {
          enabled = true;
          address = "https://vault.43mar.io:8200";
        };
      };
    };

    systemd.services.nomad = {
      wants = ["network-online.target" "mount_fs.service"];
      after = ["network-online.target" "mount_fs.service"];
      serviceConfig = {
        restartSec = 10;
      };
      path = [ pkgs.consul pkgs.vault ];
    };
  };
}
