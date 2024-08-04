cd ~/src/nix-config/vm_hosts/nixos-config/
nixos-rebuild switch --target-host alfa --build-host alfa --fast --flake '.#alfa'  --use-remote-sudo  --show-trace