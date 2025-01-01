# Recursive DNS server
{
  config,
  lib,
  pkgs,
  ...
}: {
  users.users.unbound = {
    isSystemUser = true;
  };

  users.groups.unbound = {
    members = ["unbound"];
  };

  # Define a systemd service to set up the chroot environment
  systemd.services.unbound-chroot-setup = {
    description = "Setup chroot environment for unbound";
    after = ["network.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
              /run/current-system/sw/bin/bash -c '\
              CHROOT_DIR=/etc/unbound; \
                # Create the chroot directory
                mkdir -p $CHROOT_DIR; \
                mkdir -p $CHROOT_DIR/dev; \
        \
                chown -R unbound:unbound $CHROOT_DIR; \
        \
                # Mount necessary filesystems
                touch $CHROOT_DIR/dev/urandom; \
                touch $CHROOT_DIR/dev/log; \
                /run/wrappers/bin/mount --bind /dev/urandom $CHROOT_DIR/dev/urandom; \
                /run/wrappers/bin/mount --bind /dev/log $CHROOT_DIR/dev/log;'\
        \
                setcap 'cap_net_bind_service=+ep' /run/current-system/sw/bin/unbound;
      '';
      RemainAfterExit = true;
    };
    wantedBy = ["multi-user.target"];
  };

  services.unbound = {
    enable = true;
    user = "unbound";
    stateDir = "/etc/unbound";
    settings = {
      server = {
        interface = "lanBond0";
        access-control = "10.0.0.0/8 allow";
        use-syslog = "yes";
        verbosity = "1";
        do-not-query-localhost = "no";
        use-caps-for-id = "no";
      };
      remote-control = {
        control-enable = true;

        server-key-file = "/etc/unbound/unbound_server.key";
        server-cert-file = "/etc/unbound/unbound_server.pem";
        control-key-file = "/etc/unbound/unbound_control.key";
        control-cert-file = "/etc/unbound/unbound_control.pem";
      };
      forward-zone = [
        {
          name = ".";
          forward-tls-upstream = "yes";
          forward-addr = [
            "1.1.1.1@853#cloudflare-dns.com"
            "8.8.8.8@853#dns.google"
          ];
        }
        {
          name = "43mar.io.";
          forward-addr = [
            "127.0.0.1@53000"
          ];
        }
      ];
    };
  };
}
