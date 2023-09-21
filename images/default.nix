{ inputs, lib, ... }:
let
  image = name:
    let
      spec = import (./. + "/${name}/") inputs;
    in
    inputs.nixos-generators.nixosGenerate {
      pkgs = import inputs.nixpkgs {
        inherit (spec) system;
        config = { allowUnfree = true; };
      };
      inherit (spec) format modules;
    };

  hosts = [
    "unifi-controller"
  ];
in
{
  flake.images = lib.genAttrs hosts image;
}
