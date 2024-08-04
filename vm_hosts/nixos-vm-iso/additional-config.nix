{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {

  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  boot.loader.grub.extraConfig = "
   serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
   terminal_input serial
   terminal_output serial
  ";

  users.users.root.openssh.authorizedKeys.keys = [
    # change this to your ssh key
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDaVLwk9SfBpCGkNGZMBocgwHZC57ezMRFDjPckFxX1zAh5dX5N+iQ9mGv5fRkkJqT/kcXHZS7t+POZa6DUvLYKX/hd7K8f8Rf02i8ecV0Y5F8uIVhyVnjKu+gJgmNVA10r+JJT1FN6ooJbqEz6iowV8YyX0mSpe4d12PxtaygbK1QbXkXOGUltpLq2Y4K1dBcGaVI1iGq9W/Jvb0/ImBzk7M6cFqD/5hOcHiVHsQ2VfNhl+zpeTtH/e1AHSCHzIhW9KjWzoATBah6LTkeU4okV8KfMTWPUULRj6Hkv4aLtNyJbk2CrZx+HTrWeSs4J/GFEyDpaVN9VjPIRpYIjxSLr1BJ/uAAdgqs837/ATHvsJ+NGTztdV0cLfCG/Qq91fnqNgrrGLJlKIO5xtBQ/EBUi3laGF7CatVxKxxq8n63k3z53auSHq4Es73ObHL3xqEM/pWwlfBkcfajhp6eiG3JcYJNwSV+exW8DAa3F0OBbl0lpnWoswnDBVBObUHFZgaE= pranjal@Pranjals-MBP.38baystate.net"
  ];
}