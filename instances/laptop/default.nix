{ nixos-hardware, ... }:
{
  modules = [
    ./configuration.nix
    nixos-hardware.nixosModules.dell-xps-15-7590
  ];

  format = "install-iso";
  system = "x86_64-linux";
  hostname = "laptop";
}
