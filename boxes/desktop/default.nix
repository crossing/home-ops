{ inputs, config, ... }:
{
  flake.nixosConfigurations.desktop =
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../../roles/workstation
        ./boot.nix
        ./hardware.nix
        ./networking.nix
        config.flake.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
      ];
    };
}
