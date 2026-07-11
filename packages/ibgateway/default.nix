{ lib, pkgs, ... }:

let
  ibcVersion = "3.24.1";
  ibc = pkgs.stdenvNoCC.mkDerivation {
    pname = "ibc";
    version = ibcVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/IbcAlpha/IBC/releases/download/${ibcVersion}/IBCLinux-${ibcVersion}.zip";
      hash = "sha256-2Z7ijMNTnjhD+wDSjcSEwlUAawBj048ICKw+8H3Yi7g=";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    unpackPhase = ''unzip "$src"'';
    installPhase = ''
      mkdir -p "$out"
      cp -R . "$out/"
      chmod +x "$out"/*.sh "$out"/scripts/*.sh
    '';
  };
  wrapper = pkgs.writeShellApplication {
    name = "ibgateway";
    runtimeInputs = [ pkgs.podman pkgs.coreutils pkgs.findutils pkgs.gnused pkgs.xvfb-run ];
    text = builtins.readFile ./wrapper.sh;
    runtimeEnv = {
      DOCKERFILE = ./Dockerfile;
      IBC_DIR = ibc;
      IBC_VERSION = ibcVersion;
      IBGATEWAY_INSTALL_URL = "https://download2.interactivebrokers.com/installers/ibgateway/latest-standalone/ibgateway-latest-standalone-linux-x64.sh";
    };
  };
in
pkgs.symlinkJoin {
  name = "ibgateway";
  paths = [ wrapper (pkgs.makeDesktopItem {
    name = "ibgateway";
    desktopName = "IB Gateway";
    genericName = "Trading Gateway";
    comment = "Interactive Brokers Gateway";
    exec = "ibgateway";
    categories = [ "Finance" ];
  }) ];
  meta = {
    description = "Interactive Brokers Gateway";
    platforms = lib.platforms.linux;
  };
}
