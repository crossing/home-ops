{ inputs, ... }:
{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./networking.nix
    ./disk.nix
    ./configuration

    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko

    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];
}
