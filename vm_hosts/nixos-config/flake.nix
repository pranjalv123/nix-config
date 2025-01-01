{
  description = "NixOS configuration for VM hosts";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  #inputs.NixVirt.url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
  #inputs.NixVirt.url = "github:AshleyYakeley/NixVirt";
  inputs.NixVirt.url = "github:pranjalv123/NixVirt";
  inputs.NixVirt.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    nixpkgs,
    disko,
    NixVirt,
    nixos-generators,
    ...
  } @ inputs: {
    nixosConfigurations.alfa = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit (inputs) NixVirt;
        inherit (inputs) nixos-generators;
      };
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        ./alfa.nix
      ];
    };

    nixosConfigurations.bravo = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        ./bravo.nix
      ];
    };

    nixosConfigurations.nomad-client-1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./vms/nomad/nomad-client-1.nix
        ./vms/nomad/nomad-client-live-update.nix
      ];
    };

    nixosConfigurations.nomad-server-1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./vms/nomad/nomad-server-1.nix
      ];
    };
  };
}
