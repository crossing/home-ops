{ lib, pkgs, ... }:

let
  mkIbkrGui = import ../tws/common.nix { inherit lib pkgs; };
in
mkIbkrGui {
  appId = "ibgateway";
  appLabel = "IB Gateway";
  cliName = "ibgateway";
  desktopName = "IB Gateway";
  genericName = "Trading Gateway";
  comment = "Interactive Brokers Gateway";
  installerUrl = "https://download2.interactivebrokers.com/installers/ibgateway/latest-standalone/ibgateway-latest-standalone-linux-x64.sh";
  defaultInstallDir = ".local/opt/ibgateway";
  defaultConfigDir = ".config/ibgateway";
  defaultLogDir = ".local/state/ibgateway";
  containerInstallRoot = "/opt/ibgateway-root";
  containerAppHome = "/opt/ibgateway-root/ibgateway";
  appLauncher = "/opt/ibgateway-root/ibgateway/ibgateway";
  installMarker = "ibgateway/ibgateway";
  ibcLayout = "ibgateway";
  ibcVersionPath = "/opt/ibgateway-root";
  restoreLaunchers = [ "ibgateway/ibgateway" ];
  gateway = true;
}
