{ lib, namespace, pkgs, ... }:

let
  localPackages = pkgs.${namespace};
  ibkrCli = localPackages."ibkr-cli";
  ibgatewayPackage = localPackages.ibgateway;

  ibkrLocal = pkgs.writeShellApplication {
    name = "ibkr-local";
    runtimeInputs = [
      ibkrCli
      ibgatewayPackage
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
    ];
    text = builtins.readFile ./ibkr-local.sh;
  };
in
pkgs.symlinkJoin {
  name = "ibkr-local";
  paths = [
    ibkrLocal
    ibgatewayPackage
  ];

  meta = {
    description = "Local Interactive Brokers runtime wrappers around ibkr-cli and IB Gateway";
    platforms = lib.platforms.linux;
  };
}
