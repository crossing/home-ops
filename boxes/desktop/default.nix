{ inputs, config, ... }:
{
  flake.nixosConfigurations.desktop =
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./boot.nix
        ./hardware.nix
        ./networking.nix

        config.flake.nixosModules.workstation
        inputs.sops-nix.nixosModules.sops

        inputs.nixos-hardware.nixosModules.common-cpu-amd
        inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
        inputs.nixos-hardware.nixosModules.common-cpu-amd-zenpower
      ];
    };
}
