{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }:
    let
      build = name:
        let
          spec = import (./instances + "/${name}.nix");
          hostnameModule = { ... }: {
            networking.hostName = spec.hostname;
            networking.useDHCP = true;
          };
        in
        nixos-generators.nixosGenerate {
          pkgs = import nixpkgs {
            inherit (spec) system;
            config = { allowUnfree = true; };
          };
          inherit (spec) format;
          modules = spec.modules ++ [ hostnameModule ];
        };
    in
    {
      packages.x86_64-linux = nixpkgs.lib.genAttrs [
        "unifi-controller"
      ]
        build;
    };
}
