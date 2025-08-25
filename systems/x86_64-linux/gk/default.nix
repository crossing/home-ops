{ inputs, modulesPath, ... }:
{
  imports = [
    ./networking.nix
    ./hardware.nix
    ./boot.nix
    ./disk.nix
    ./configuration

    (modulesPath + "/profiles/minimal.nix")
    inputs.disko.nixosModules.disko
  ];

  server.enable = true;
}
