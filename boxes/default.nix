{ config, lib, inputs, ... }:
{
  imports = [
    ./desktop
    ./pi

    ../roles
  ];

  flake.deploy.nodes = lib.mapAttrs
    (_: nixosConfiguration: {
      hostname = nixosConfiguration.config.networking.hostName;
      profiles.system = {
        user = "root";
        sshUser = "root";
        path = inputs.deploy-rs.lib.${nixosConfiguration.config.nixpkgs.hostPlatform.system}.activate.nixos nixosConfiguration;
      };
    })
    config.flake.nixosConfigurations;
}
