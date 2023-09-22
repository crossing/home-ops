{ inputs, config, ... }:
{
  flake.nixosConfigurations.laptop =
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./boot.nix
        ./hardware.nix
        ./networking.nix

        config.flake.nixosModules.home-manager
        config.flake.nixosModules.workstation

        inputs.nixos-hardware.nixosModules.dell-xps-15-7590
        inputs.sops-nix.nixosModules.sops
      ];
    };
}
