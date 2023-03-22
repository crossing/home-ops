{ nixos-hardware, home-manager, ... }:
{
  modules = [
    ../../roles/workstation
    ../../roles/home
    ./boot.nix
    ./hardware.nix
    ./networking.nix
    home-manager.nixosModules.home-manager
  ];

  system = "x86_64-linux";
}
