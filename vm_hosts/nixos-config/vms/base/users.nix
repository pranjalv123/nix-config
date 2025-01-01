{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  security.sudo.wheelNeedsPassword = false;

  users.users.pranjal = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
    ];
    password = "nixos";
    #initialHashedPassword = "$y$j9T$axd6qLrrVRj4yr1.DsgDk/$spn2i/5Jtr4a67/CN9a.Dr6dMGwRsst8IA4C8LN0R/A";
  };
}
