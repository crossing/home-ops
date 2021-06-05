{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-22.05";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, nixos-generators, nixos-hardware, ... }:
    let
      hosts = import ./hosts.nix {
        inherit nixpkgs nixos-generators nixos-hardware;
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
