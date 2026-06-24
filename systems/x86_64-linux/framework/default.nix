{ inputs, ... }:
{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./networking.nix
    ./configuration

    inputs.sops-nix.nixosModules.sops

    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];
}
