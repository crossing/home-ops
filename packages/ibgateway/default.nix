{ lib, pkgs, ... }:

let
  ibcVersion = "3.24.1";
  ibgatewayVersion = "10.48";
  ibgatewayInstaller = pkgs.fetchurl {
    name = "ibgateway-${ibgatewayVersion}-standalone-linux-x64.sh";
    url = "https://download2.interactivebrokers.com/installers/ibgateway/latest-standalone/ibgateway-latest-standalone-linux-x64.sh";
    hash = "sha256-5zwXjP5B7Qfe/so7OggmZY8p1XgKj9dZSGjrvoSQ9Fs=";
  };
  ibc = pkgs.stdenvNoCC.mkDerivation {
    pname = "ibc";
    version = ibcVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/IbcAlpha/IBC/releases/download/${ibcVersion}/IBCLinux-${ibcVersion}.zip";
      hash = "sha256-2Z7ijMNTnjhD+wDSjcSEwlUAawBj048ICKw+8H3Yi7g=";
    };
    patches = [ ./ibc-autorestart-builtins.patch ];
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
      IBGATEWAY_INSTALLER = ibgatewayInstaller;
    };
  };
in
pkgs.symlinkJoin {
  name = "ibgateway";
  passthru = { inherit ibc; };
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
