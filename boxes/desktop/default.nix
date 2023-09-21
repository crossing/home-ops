{ inputs, ... }:
{
  flake.nixosConfigurations.desktop =
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../../roles/workstation
        (import ../../roles/home inputs)
        ./boot.nix
        ./hardware.nix
        ./networking.nix
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
      ];
    };
}
