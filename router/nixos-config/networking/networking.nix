{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  imports = [
    ./interfaces.nix
    ./routing.nix
    ./dhcp.nix
    ./vlans.nix
    ./pxe.nix
    ./dns-unbound.nix
    ./dns-bind.nix
    #./tailscale.nix
    # ./dns.nix
  ];
  options = {
    vlans.vlans = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = ''
        List of VLANs to create.
      '';
    };
  };
  config = {
    networking.networkmanager.enable = false;
    networking.useDHCP = false;
    systemd.network.enable = true;
  };
}
