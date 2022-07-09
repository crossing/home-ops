{ nixpkgs, nixos-generators }:
let
  inherit (nixpkgs) lib;
  modules = spec:
    let
      hostnameModule = { ... }: {
        networking.hostName = spec.hostname;
        networking.useDHCP = true;
      };
    in
    spec.modules ++ [ hostnameModule ];

  image = spec: nixos-generators.nixosGenerate {
    pkgs = import nixpkgs {
      inherit (spec) system;
      config = { allowUnfree = true; };
    };
    inherit (spec) format;
    modules = modules spec;
  };

  deployment = spec:
    let
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

  mapHost = f: name:
    let
      spec = import (./instances + "/${name}.nix");
    in
    f spec;

  hosts = [ "unifi-controller" ];
in
{
  images = lib.genAttrs hosts (mapHost image);
  deployments = lib.genAttrs hosts (mapHost deployment);
}
