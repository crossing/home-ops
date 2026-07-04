{ lib, namespace, pkgs, ... }:

let
  localPackages = pkgs.${namespace};
  ibkrCli = localPackages."ibkr-cli";
  ibgatewayPackage = localPackages.ibgateway;
  twsPackage = localPackages.tws;

  ibkrLocal = pkgs.writeShellApplication {
    name = "ibkr-local";
    runtimeInputs = [
      ibkrCli
      ibgatewayPackage
      twsPackage
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.imagemagick
      pkgs.jdk
      pkgs.jq
      pkgs.wmctrl
      pkgs.xdotool
      pkgs.xvfb-run
    ];
    text = builtins.readFile ./ibkr-local.sh;
  };
in
pkgs.symlinkJoin {
  name = "ibkr-local";
  paths = [
    ibkrLocal
    ibgatewayPackage
    twsPackage
  ];

  meta = {
    description = "Local Interactive Brokers runtime wrappers around ibkr-cli and TWS";
    platforms = lib.platforms.linux;
  };
}
