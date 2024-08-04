{
  description = "Nixos router config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: {
    nixosConfigurations.router1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./router-1.nix
        ./configuration.nix
      ];
    };

    nixosConfigurations.router2 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./router-2.nix
        ./configuration.nix
      ];
    };
  };
}
