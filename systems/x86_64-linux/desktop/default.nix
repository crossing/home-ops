{ inputs, ... }:
{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./networking.nix

    inputs.self.nixosModules.workstation
    inputs.sops-nix.nixosModules.sops

    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
  ];
}
