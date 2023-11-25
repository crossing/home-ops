{ withSystem, inputs, config, ... }:
{
  flake.nixosConfigurations.pi =
    inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./networking.nix
        ./hardware.nix
        ./reboot.nix

        config.flake.nixosModules.unifi-controller
        config.flake.nixosModules.server

        inputs.disko.nixosModules.disko
      ];
    };
}
