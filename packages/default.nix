{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.easyOverlay
  ];

  perSystem = { pkgs, final, config, ... }: {
    packages.pyroveil = pkgs.callPackage ./pyroveil.nix { };

    overlayAttrs = {
      inherit (config.packages) pyroveil;
    };
  };
}
