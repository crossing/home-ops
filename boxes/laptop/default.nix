{ nixos-hardware, home-manager, ... }:
{
  modules = [
    ./configuration.nix
    nixos-hardware.nixosModules.dell-xps-15-7590
    home-manager.nixosModules.home-manager
    ./home
  ];

  format = "install-iso";
  system = "x86_64-linux";
  hostname = "laptop";
}
