{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs.url = "github:serokell/deploy-rs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };


  outputs = { self, nixpkgs, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./devShell.nix
        ./boxes
        ./images
        ./home-manager
        ./packages
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem = { pkgs, system, ... }: {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      };
    };
}
