{ withSystem, inputs, config, ... }:
{
  flake.nixosConfigurations.gk =
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        ./networking.nix
        ./hardware.nix
        ./unifi.nix
        ./boot.nix
        ./disk.nix

        config.flake.nixosModules.unifi-controller
        config.flake.nixosModules.server

        inputs.disko.nixosModules.disko
      ];
    };
}
