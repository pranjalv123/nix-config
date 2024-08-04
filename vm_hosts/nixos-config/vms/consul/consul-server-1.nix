{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./consul-server-base.nix];
  consul.index = "1";
}