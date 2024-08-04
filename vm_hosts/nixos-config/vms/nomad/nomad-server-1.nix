{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./nomad-server-base.nix];
  nomad.index = "1";
}