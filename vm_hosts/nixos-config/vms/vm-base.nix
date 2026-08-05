{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./base/ssh.nix ./base/users.nix ./base/filesystem.nix];

  security.pki.certificateFiles = [./ca.crt];
  networking.firewall.enable = false;
  networking.useDHCP = lib.mkDefault true;

  # network-online.target was being reached when dhcpcd merely *started*, ~4s
  # before it actually leased an address. Consul and Nomad both key off the
  # interface address at startup, so they came up, found nothing, and died.
  # Make dhcpcd hold the target until an IPv4 lease exists.
  networking.dhcpcd.wait = "ipv4";

  nix.settings.experimental-features = "nix-command flakes";
  environment.systemPackages = [pkgs.python3 pkgs.vim pkgs.dig];

  system.stateVersion = "23.11";
}
