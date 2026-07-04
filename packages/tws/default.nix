{ pkgs, lib, ... }:

let
  ibcVersion = "3.24.1";
  ibcZip = pkgs.fetchurl {
    url = "https://github.com/IbcAlpha/IBC/releases/download/${ibcVersion}/IBCLinux-${ibcVersion}.zip";
    hash = "sha256-2Z7ijMNTnjhD+wDSjcSEwlUAawBj048ICKw+8H3Yi7g=";
  };

  ibc = pkgs.stdenvNoCC.mkDerivation {
    pname = "ibc";
    version = ibcVersion;
    src = ibcZip;
    nativeBuildInputs = [ pkgs.unzip ];

    unpackPhase = ''
      unzip "$src"
    '';

    installPhase = ''
      mkdir -p "$out"
      cp -R . "$out/"
      chmod +x "$out"/*.sh "$out"/scripts/*.sh
    '';
  };
in

pkgs.symlinkJoin {
  name = "tws";

  paths = [
    (pkgs.writeShellApplication {
      name = "tws";
      runtimeInputs = [
        pkgs.podman
        pkgs.coreutils
        pkgs.gnused
        pkgs.xvfb-run
      ];
      text = builtins.readFile ./wrapper.sh;
      runtimeEnv = {
        DOCKERFILE = ./Dockerfile;
        IBC_DIR = ibc;
        IBC_VERSION = ibcVersion;
      };
    })

    (pkgs.makeDesktopItem {
      name = "tws";
      desktopName = "Trader Workstation";
      genericName = "Trading Platform";
      comment = "Interactive Brokers Trader Workstation";
      exec = "tws";
      categories = [ "Finance" ];
    })
  ];
}
