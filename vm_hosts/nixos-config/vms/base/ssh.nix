{
  modulesPath,
  config,
  lib,
  pkgs,
  ...
}: {
  services.openssh.enable = true;

  systemd.services.copy_ssh_keys = {
    wantedBy = ["multi-user.target" "sshd.service"];
    after = ["mount_fs.service"];
    wants = ["mount_fs.service"];
    before = ["sshd.service"];
    script = ''
      ls /persist
      ls /persist/ssh_keys
      if [ ! -f /persist/ssh_keys/ssh_host_rsa_key ]; then
        echo "Generating RSA key"
        /run/current-system/sw/bin/ssh-keygen -t rsa -b 4096 -f /persist/ssh_keys/ssh_host_rsa_key -N ""
      fi
      if [ ! -f /persist/ssh_keys/ssh_host_ed25519_key ]; then
        echo "Generating ED25519 key"
        /run/current-system/sw/bin/ssh-keygen -t ed25519 -f /persist/ssh_keys/ssh_host_ed25519_key -N ""
      fi
      cp /persist/ssh_keys/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
      cp /persist/ssh_keys/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
      cp /persist/ssh_keys/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
      cp /persist/ssh_keys/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
      echo "Copied keys"
    '';
  };

  users.users.pranjal.openssh.authorizedKeys.keys = [
    # change this to your ssh key
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDaVLwk9SfBpCGkNGZMBocgwHZC57ezMRFDjPckFxX1zAh5dX5N+iQ9mGv5fRkkJqT/kcXHZS7t+POZa6DUvLYKX/hd7K8f8Rf02i8ecV0Y5F8uIVhyVnjKu+gJgmNVA10r+JJT1FN6ooJbqEz6iowV8YyX0mSpe4d12PxtaygbK1QbXkXOGUltpLq2Y4K1dBcGaVI1iGq9W/Jvb0/ImBzk7M6cFqD/5hOcHiVHsQ2VfNhl+zpeTtH/e1AHSCHzIhW9KjWzoATBah6LTkeU4okV8KfMTWPUULRj6Hkv4aLtNyJbk2CrZx+HTrWeSs4J/GFEyDpaVN9VjPIRpYIjxSLr1BJ/uAAdgqs837/ATHvsJ+NGTztdV0cLfCG/Qq91fnqNgrrGLJlKIO5xtBQ/EBUi3laGF7CatVxKxxq8n63k3z53auSHq4Es73ObHL3xqEM/pWwlfBkcfajhp6eiG3JcYJNwSV+exW8DAa3F0OBbl0lpnWoswnDBVBObUHFZgaE= pranjal@Pranjals-MBP.38baystate.net"
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    # change this to your ssh key
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDaVLwk9SfBpCGkNGZMBocgwHZC57ezMRFDjPckFxX1zAh5dX5N+iQ9mGv5fRkkJqT/kcXHZS7t+POZa6DUvLYKX/hd7K8f8Rf02i8ecV0Y5F8uIVhyVnjKu+gJgmNVA10r+JJT1FN6ooJbqEz6iowV8YyX0mSpe4d12PxtaygbK1QbXkXOGUltpLq2Y4K1dBcGaVI1iGq9W/Jvb0/ImBzk7M6cFqD/5hOcHiVHsQ2VfNhl+zpeTtH/e1AHSCHzIhW9KjWzoATBah6LTkeU4okV8KfMTWPUULRj6Hkv4aLtNyJbk2CrZx+HTrWeSs4J/GFEyDpaVN9VjPIRpYIjxSLr1BJ/uAAdgqs837/ATHvsJ+NGTztdV0cLfCG/Qq91fnqNgrrGLJlKIO5xtBQ/EBUi3laGF7CatVxKxxq8n63k3z53auSHq4Es73ObHL3xqEM/pWwlfBkcfajhp6eiG3JcYJNwSV+exW8DAa3F0OBbl0lpnWoswnDBVBObUHFZgaE= pranjal@Pranjals-MBP.38baystate.net"
  ];
}
