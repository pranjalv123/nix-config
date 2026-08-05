{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
    services.envoy.enable = true;
    services.consul = {
      enable = true;
      extraConfig = {
        datacenter = "dc1";
        data_dir = "/persist/consul";

        retry_join = ["consul-server-1.43mar.io"];

        ports = {
          grpc = 8502;
          grpc_tls = 8503;
        };
        connect = {
          enabled = true;
        };
        verify_incoming = true;
        verify_outgoing = true;
        verify_server_hostname = true;
        ca_file = "/persist/vault-agent/ca.crt";
        auto_encrypt = {
          tls = true;
        };
        # bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/8\" | attr \"address\" }}";
        bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"192.168.1.0/24\" | attr \"address\" }}";

      };

    };
    systemd.services.consul = {
      wants = ["network-online.target" "mount_fs.service"];
      after = ["network-online.target" "mount_fs.service"];
      serviceConfig = {
        # Was `restartSec` — systemd logged "Unknown key 'restartSec', ignoring"
        # and fell back to the 100ms default, so all 10 restarts burned in ~4s,
        # before DHCP had handed out an address.
        RestartSec = 10;
        Restart = lib.mkForce "always";
        Type = "notify";
      };
      startLimitBurst = lib.mkForce 10;
      startLimitIntervalSec = 300;
    };
}