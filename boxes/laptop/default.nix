{ withSystem, inputs, ... }:
{
  flake.nixosConfigurations.laptop =
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../../roles/workstation
        (import ../../roles/home inputs)
        ./boot.nix
        ./hardware.nix
        ./networking.nix
        inputs.nixos-hardware.nixosModules.dell-xps-15-7590
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
      ];
    };
}
