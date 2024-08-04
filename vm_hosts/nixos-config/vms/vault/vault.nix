{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [../vm-base.nix ../base/vault-agent.nix];

  cert.serviceToReload = ["vault"];
  cert.altNames = "vault";

  networking.hostName = "vault";

  users.groups.vault = {};
  users.users.vault = {
    isSystemUser = true;
    group = "vault";
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = [pkgs.vault];
  services.vault = {
    package = pkgs.vault-bin;
    enable = true;
    address = "[::]:8200";
    storagePath = "/persist/vault";
    storageBackend = "raft";
    extraSettingsPaths = ["/persist/config/"];
    extraConfig = ''
      api_addr     = "https://vault.43mar.io:8200"
      cluster_addr = "https://vault.43mar.io:8201"
      ui           = true
    '';
    storageConfig = ''
      node_id = "vault-1"
    '';
    tlsCertFile = "/persist/vault-agent/cert.pem";
    tlsKeyFile = "/persist/vault-agent/key.pem";
  };

  systemd.services.vault = {
    wants = ["network-online.target" "mount_fs.service"];
    after = ["network-online.target" "mount_fs.service"];
    preStart = "/run/current-system/sw/bin/sleep 10";
    serviceConfig = {
      restartSec = 10;
    };
    startLimitBurst = lib.mkForce  10;
  };
}
