{ withSystem, inputs, config, ... }:
{
  flake.nixosConfigurations.unifi-controller =
    inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./networking.nix

        config.flake.nixosModules.unifi-controller

        inputs.nixos-generators.nixosModules.sd-aarch64
      ];
    };
}
