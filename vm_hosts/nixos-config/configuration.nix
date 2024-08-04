{
  modulesPath,
  config,
  lib,
  pkgs,
  NixVirt,
  ...
}: {
  nixpkgs.config.allowUnfree = true;
  networking.firewall.enable = false;
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "04:45" ];
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 7d";
  };

  nix.settings.experimental-features = "nix-command flakes";
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    NixVirt.nixosModules.default
    ./virtualization.nix
    ./disk-config.nix
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;
  environment.etc."vault-ca-keys.pem".source = ./ssh_ca;
  services.openssh.extraConfig = "TrustedUserCAKeys /etc/ssh/vault-ca-keys.pub";

  services.target.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.virt-manager
  ];

  security.sudo.wheelNeedsPassword = false;

  users.users.pranjal = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
    ];
    initialHashedPassword = "$y$j9T$axd6qLrrVRj4yr1.DsgDk/$spn2i/5Jtr4a67/CN9a.Dr6dMGwRsst8IA4C8LN0R/A";
  };
  users.users.root.initialHashedPassword = "$y$j9T$axd6qLrrVRj4yr1.DsgDk/$spn2i/5Jtr4a67/CN9a.Dr6dMGwRsst8IA4C8LN0R/A";

  users.users.pranjal.openssh.authorizedKeys.keys = [
    # change this to your ssh key
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDaVLwk9SfBpCGkNGZMBocgwHZC57ezMRFDjPckFxX1zAh5dX5N+iQ9mGv5fRkkJqT/kcXHZS7t+POZa6DUvLYKX/hd7K8f8Rf02i8ecV0Y5F8uIVhyVnjKu+gJgmNVA10r+JJT1FN6ooJbqEz6iowV8YyX0mSpe4d12PxtaygbK1QbXkXOGUltpLq2Y4K1dBcGaVI1iGq9W/Jvb0/ImBzk7M6cFqD/5hOcHiVHsQ2VfNhl+zpeTtH/e1AHSCHzIhW9KjWzoATBah6LTkeU4okV8KfMTWPUULRj6Hkv4aLtNyJbk2CrZx+HTrWeSs4J/GFEyDpaVN9VjPIRpYIjxSLr1BJ/uAAdgqs837/ATHvsJ+NGTztdV0cLfCG/Qq91fnqNgrrGLJlKIO5xtBQ/EBUi3laGF7CatVxKxxq8n63k3z53auSHq4Es73ObHL3xqEM/pWwlfBkcfajhp6eiG3JcYJNwSV+exW8DAa3F0OBbl0lpnWoswnDBVBObUHFZgaE= pranjal@Pranjals-MBP.38baystate.net"
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    # change this to your ssh key
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDaVLwk9SfBpCGkNGZMBocgwHZC57ezMRFDjPckFxX1zAh5dX5N+iQ9mGv5fRkkJqT/kcXHZS7t+POZa6DUvLYKX/hd7K8f8Rf02i8ecV0Y5F8uIVhyVnjKu+gJgmNVA10r+JJT1FN6ooJbqEz6iowV8YyX0mSpe4d12PxtaygbK1QbXkXOGUltpLq2Y4K1dBcGaVI1iGq9W/Jvb0/ImBzk7M6cFqD/5hOcHiVHsQ2VfNhl+zpeTtH/e1AHSCHzIhW9KjWzoATBah6LTkeU4okV8KfMTWPUULRj6Hkv4aLtNyJbk2CrZx+HTrWeSs4J/GFEyDpaVN9VjPIRpYIjxSLr1BJ/uAAdgqs837/ATHvsJ+NGTztdV0cLfCG/Qq91fnqNgrrGLJlKIO5xtBQ/EBUi3laGF7CatVxKxxq8n63k3z53auSHq4Es73ObHL3xqEM/pWwlfBkcfajhp6eiG3JcYJNwSV+exW8DAa3F0OBbl0lpnWoswnDBVBObUHFZgaE= pranjal@Pranjals-MBP.38baystate.net"
  ];

  system.stateVersion = "23.11";
}
