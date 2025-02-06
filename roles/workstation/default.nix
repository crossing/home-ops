{ inputs, ... }:
{
  flake.nixosModules.workstation = { config, ... }: {
    imports = [
      ./main.nix
      ../common.nix
    ];

    nixpkgs.overlays = [
      (final: prev: {
        docker = inputs.nixpkgs-unstable.legacyPackages.${config.nixpkgs.hostPlatform.system}.docker;
      })
    ];
  };
}
