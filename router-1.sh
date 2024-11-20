cd ~/src/nix-config/router/nixos-config/
nixos-rebuild switch --target-host 10.0.0.1 --build-host 10.0.0.1 --fast --flake '.#router1'  --use-remote-sudo  --show-trace