{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, nixos-generators, ... }:
    let
      hosts = import ./hosts.nix {
        inherit nixpkgs;
        inherit (nixpkgs) lib;
        inherit nixos-generators;
      };
    in
    {
      colmena = { meta.nixpkgs = import nixpkgs { }; } // hosts.deployments;
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = hosts.images;

        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.colmena ];
        };
      });
}
