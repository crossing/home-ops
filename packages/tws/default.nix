{ lib, pkgs, ... }:

let
  mkIbkrGui = import ./common.nix { inherit lib pkgs; };
in
mkIbkrGui {
  appId = "tws";
  appLabel = "TWS";
  cliName = "tws";
  desktopName = "Trader Workstation";
  genericName = "Trading Platform";
  comment = "Interactive Brokers Trader Workstation";
  installerUrl = "https://download2.interactivebrokers.com/installers/tws/latest-standalone/tws-latest-standalone-linux-x64.sh";
  defaultInstallDir = ".local/opt/tws";
  defaultConfigDir = ".config/tws";
  defaultLogDir = ".local/state/tws";
  containerInstallRoot = "/opt/tws";
  containerAppHome = "/opt/tws";
  appLauncher = "/opt/tws/tws";
  installMarker = "tws";
  ibcLayout = "tws";
  ibcVersionPath = "/opt/tws";
  restoreLaunchers = [
    "tws"
    "ibgateway"
  ];
}
