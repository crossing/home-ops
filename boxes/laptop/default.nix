{ nixos-hardware, home-manager, ... }:
{
  modules = [
    ../../roles/laptop
    ../../roles/home
    ./boot.nix
    ./hardware.nix
    ./networking.nix
    nixos-hardware.nixosModules.dell-xps-15-7590
    home-manager.nixosModules.home-manager
  ];

  system = "x86_64-linux";
}
