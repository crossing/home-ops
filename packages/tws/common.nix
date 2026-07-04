{ lib, pkgs }:

{
  appId,
  appLabel,
  cliName,
  desktopName,
  genericName,
  comment,
  installerUrl,
  defaultInstallDir,
  defaultConfigDir,
  defaultLogDir,
  containerInstallRoot,
  containerAppHome,
  appLauncher,
  installMarker,
  ibcLayout,
  ibcVersionPath,
  restoreLaunchers,
  gateway ? false,
}:

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
  name = cliName;

  paths = [
    (pkgs.writeShellApplication {
      name = cliName;
      runtimeInputs = [
        pkgs.podman
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnused
        pkgs.xvfb-run
      ];
      text = builtins.readFile ./wrapper.sh;
      runtimeEnv = {
        DOCKERFILE = ./Dockerfile;
        IBC_DIR = ibc;
        IBC_VERSION = ibcVersion;
        IBKR_APP_ID = appId;
        IBKR_APP_LABEL = appLabel;
        IBKR_APP_CLI_NAME = cliName;
        IBKR_INSTALL_URL = installerUrl;
        IBKR_DEFAULT_INSTALL_DIR = defaultInstallDir;
        IBKR_DEFAULT_CONFIG_DIR = defaultConfigDir;
        IBKR_DEFAULT_LOG_DIR = defaultLogDir;
        IBKR_CONTAINER_INSTALL_ROOT = containerInstallRoot;
        IBKR_CONTAINER_APP_HOME = containerAppHome;
        IBKR_APP_LAUNCHER = appLauncher;
        IBKR_INSTALL_MARKER = installMarker;
        IBKR_IBC_LAYOUT = ibcLayout;
        IBKR_IBC_VERSION_PATH = ibcVersionPath;
        IBKR_IS_GATEWAY = if gateway then "1" else "0";
        IBKR_RESTORE_LAUNCHERS = lib.concatStringsSep " " restoreLaunchers;
      };
    })

    (pkgs.makeDesktopItem {
      name = cliName;
      inherit desktopName genericName comment;
      exec = cliName;
      categories = [ "Finance" ];
    })
  ];

  meta = {
    description = comment;
    platforms = lib.platforms.linux;
  };
}
