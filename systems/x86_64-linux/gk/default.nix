{ inputs, ... }:
{
  imports = [
    ./networking.nix
    ./hardware.nix
    ./unifi.nix
    ./boot.nix
    ./disk.nix

    inputs.self.nixosModules.unifi-controller
    inputs.self.nixosModules.server

    inputs.disko.nixosModules.disko
  ];
}
