{
  inputs = {
    nixpkgs.url = "nixpkgs/release-22.11";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-22.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , nixos-generators
    , nixos-hardware
    , home-manager
    , ...
    }:
    let
      hosts = import ./hosts.nix {
        inherit nixpkgs nixos-generators nixos-hardware home-manager;
      };
    in
    {
      colmena = { meta.nixpkgs = import nixpkgs { }; } // hosts.deployments;
      inherit (hosts) images nixosConfigurations;
    } //
    flake-utils.lib.eachDefaultSystem (system:
    let pkgs = import nixpkgs { inherit system; };
    in
    {
      devShell = pkgs.mkShell {
        buildInputs = [ pkgs.colmena ];
      };
    });
}
