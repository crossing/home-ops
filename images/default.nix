{ nixpkgs, nixos-generators, ... }@args:
let
  inherit (nixpkgs) lib;

  image = name:
    let
      spec = import (./. + "/${name}/") args;
    in
    nixos-generators.nixosGenerate {
      pkgs = import nixpkgs {
        inherit (spec) system;
        config = { allowUnfree = true; };
      };
      inherit (spec) format modules;
    };

  hosts = [
    "unifi-controller"
  ];
in
lib.genAttrs hosts image
