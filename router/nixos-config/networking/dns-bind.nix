# Authoritative DNS server for local hosts

{
  config,
  lib,
  pkgs,
  ...
}: {

  environment.etc."bind/bind-setup" = {
    enable = true;
    user = "named";
    group = "named";
    mode = "0744";
    text = ''

    mkdir -p /var/run/bind


    cat <<EOF > /var/run/bind/43mar.io.zone
\$TTL    604800
@       IN      SOA    localhost. admin.43mar.io. (
                     2024060800         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      localhost.
@       IN      A       127.0.0.1
@       IN      AAAA    ::1
router-1 IN     A       10.0.0.1
EOF
    chown -R named:named /var/run/bind
    chmod 0744 /var/run/bind


    '';
  };
systemd.services.bind-setup = {
    description = "Setup environment for bind";
    after = ["network.target"];
    restartTriggers = ["/etc/bind/bind-setup"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''/run/current-system/sw/bin/bash /etc/bind/bind-setup'';
      RemainAfterExit = true;
    };
    wantedBy = ["multi-user.target"];
  };
services.bind = {
  enable = true;
  cacheNetworks = [ "127.0.0.0/24" ];
  listenOn = [ ];
  ipv4Only = true;
  directory = "/var/run/bind";
  extraOptions = ''
  recursion no;
  listen-on port 53000 { 127.0.0.1; };
  '';
  zones = [
    {
      name = "43mar.io";
      file = "/var/zones/43mar.io.zone";
      master = true;
      extraConfig = ''
        allow-update {127.0.0.1;}; // DDNS this host only
      '';
    }
  ];
};
}
