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

  nix.settings.experimental-features = "nix-command flakes";
  environment.systemPackages = [pkgs.python3 pkgs.vim pkgs.dig];

  system.stateVersion = "23.11";
}
