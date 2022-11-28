{ nixpkgs, nixos-generators, nixos-hardware, home-manager, deploy-rs, ... }:
let
  inherit (nixpkgs) lib;

  config = spec: nixpkgs.lib.nixosSystem {
    inherit (spec) system modules;
  };

  deploy = spec:
    let
      nixosConfiguration = config spec;
    in
    {
      hostname = nixosConfiguration.config.networking.hostName;
      profiles.system = {
        user = "root";
        sshUser = "root";
        path = deploy-rs.lib.${spec.system}.activate.nixos nixosConfiguration;
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
  deploy.nodes = lib.genAttrs hosts (mapHost deploy);
}
