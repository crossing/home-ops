{ nixos-hardware, home-manager, sops-nix, ... }@inputs:
{
  modules = [
    ../../roles/workstation
    (import ../../roles/home inputs)
    ./boot.nix
    ./hardware.nix
    ./networking.nix
    home-manager.nixosModules.home-manager
    sops-nix.nixosModules.sops
  ];

  system = "x86_64-linux";
}
