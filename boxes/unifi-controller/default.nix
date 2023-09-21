{ withSystem, inputs, ... }:
{
  flake.nixosConfigurations.unifi-controller =
    inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ../../roles/unifi-controller
        ./networking.nix
        inputs.nixos-generators.nixosModules.sd-aarch64
      ];
    };
}
