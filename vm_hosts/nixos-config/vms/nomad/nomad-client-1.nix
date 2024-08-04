{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./nomad-client-base.nix (modulesPath + "/profiles/qemu-guest.nix")];
  nomad.index = "1";




    swapDevices = [ ];

    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking

}