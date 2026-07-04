{ inputs, lib, pkgs, ... }:

let
  ibkrCli = pkgs.callPackage ../ibkr-cli { inherit inputs; };
  twsPackage = pkgs.callPackage ../tws { };

  ibkrLocal = pkgs.writeShellApplication {
    name = "ibkr-local";
    runtimeInputs = [
      ibkrCli
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
    twsPackage
  ];

  meta = {
    description = "Local Interactive Brokers runtime wrappers around ibkr-cli and TWS";
    platforms = lib.platforms.linux;
  };
}
