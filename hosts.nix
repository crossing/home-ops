{ nixpkgs, lib, nixos-generators }:
let
  getSpec = name: import (./instances + "/${name}.nix");
  modules = spec:
    let
      hostnameModule = { ... }: {
        networking.hostName = spec.hostname;
        networking.useDHCP = true;
      };
    in
    spec.modules ++ [ hostnameModule ];

  image = name:
    let
      spec = getSpec name;
    in
    nixos-generators.nixosGenerate {
      pkgs = import nixpkgs {
        inherit (spec) system;
        config = { allowUnfree = true; };
      };
      inherit (spec) format;
      modules = modules spec;
    };

  deployment = name:
    let
      spec = getSpec name;
      formatModule = nixos-generators.nixosModules."${spec.format}";
    in
    { name, nodes, pkgs, ... }: {
      deployment = {
        targetHost = spec.hostname;
        targetUser = "root";
        replaceUnknownProfiles = false;
      };

      imports = (modules spec) ++ [ formatModule ];
      nixpkgs = {
        inherit (spec) system;
        config.allowUnfree = true;
      };
    };

  hosts = [ "unifi-controller" ];
in
{
  images = lib.genAttrs hosts image;
  deployments = lib.genAttrs hosts deployment;
}
