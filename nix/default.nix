{ sources ? import ./sources.nix }:
let
  overlay = import ./overlay.nix;
  pkgs = import sources.nixpkgs {
    overlays = [ overlay ];
  };
in pkgs
