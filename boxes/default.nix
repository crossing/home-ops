{ nixpkgs, nixos-generators, nixos-hardware, home-manager, ... }:
let
  inherit (nixpkgs) lib;
  modules = spec: spec.modules;

  config = spec: nixpkgs.lib.nixosSystem {
    inherit (spec) system;
    modules = (modules spec);
  };

  deployment = spec:
    { name, nodes, pkgs, ... }:
    let
      conf = config spec;
      hostname = conf.config.networking.hostName;
    in
    {
      deployment = {
        targetHost = hostname;
        targetUser = "root";
        replaceUnknownProfiles = false;
      };

      imports = modules spec;
      nixpkgs = {
        inherit (spec) system;
        config.allowUnfree = true;
      };
    };

  mapHost = f: name:
    let
      spec = import (./. + "/${name}/") {
        inherit nixos-hardware home-manager nixos-generators;
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
  deployments = lib.genAttrs hosts (mapHost deployment);
}
