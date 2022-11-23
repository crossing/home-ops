{ nixpkgs, nixos-generators, nixos-hardware, home-manager }:
let
  inherit (nixpkgs) lib;
  modules = spec:
    let
      hostnameModule = { ... }: {
        networking.hostName = spec.hostname;
        networking.useDHCP = lib.mkDefault true;
      };
    in
    spec.modules ++ [ hostnameModule ];

  config = spec: nixpkgs.lib.nixosSystem {
    inherit (spec) system;
    modules = (modules spec);
  };

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
      spec = import (./boxes + "/${name}/") {
        inherit nixos-hardware home-manager;
      };
    in
    f spec;

  hosts = [
    "unifi-controller"
    "laptop"
  ];
in
{
  nixosConfigurations = lib.genAttrs hosts (mapHost config);
  images = lib.genAttrs hosts (mapHost image);
  deployments = lib.genAttrs hosts (mapHost deployment);
}
