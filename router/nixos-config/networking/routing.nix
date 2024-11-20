{lib, ...}: {
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = true;

  networking.firewall.enable = false;
  networking.nftables.enable = true;

  # input should drop; forward should drop
  networking.nftables.tables = {
    local_traffic = {
      family = "inet";
      content = ''
        chain output {
          type filter hook output priority 0; policy accept;
        }

        chain input {
          type filter hook input priority 0; policy drop;

          iifname "lo" accept comment "Allow all traffic on loopback interface";
          ct state established accept comment "Allow established connections";

          iifname "lanBond0" accept comment "Allow all traffic on lanBond0 (for now at least)";

          # iifname "tailscale0" accept comment "Allow all traffic on tailscale0 (for now at least)";

          iifname "wan0" drop

          iifname "lanBond0" ip protocol icmp accept comment "Allow all icmp traffic on lan0";
          iifname "lanBond0" udp dport {67, 68} accept comment "Allow DHCP traffic on lan0";
          iifname "lanBond0" udp dport {53} accept comment "Allow DNS traffic on lan0";

          iifname "mgmt0" tcp dport 22 accept comment "Allow SSH traffic on mgmt0";
          iifname "vlan-mgmt" tcp dport 22 accept comment "Allow SSH traffic on management vlan";
          iifname "vlan-admin" tcp dport 22 accept comment "Allow SSH traffic on admin vlan";

          icmp type echo-request limit rate 5/second accept;
        }
      '';
    };

    nat = {
      family = "inet";
      content = ''
        chain prerouting {
          type nat hook prerouting priority 0; policy accept;
        }

        chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            oifname "wan0" masquerade
        }
      '';
    };

    inter_vlan = {
      family = "inet";
      content = ''
        chain forward {
            type filter hook forward priority 0; policy accept;

            ct state established accept comment "Allow established connections";

            iifname "vlan-admin" accept comment "Allow traffic from admin to anywhere";
            iifname "vlan-guest" oifname wan0 accept comment "Allow traffic from guest to internet";
            iifname "vlan-server" oifname wan0 accept comment "Allow traffic from servers to internet";
            iifname "vlan-server" oifname "vlan-iot" accept comment "Allow traffic from servers to IOT"
        }
      '';
    };
  };
}
