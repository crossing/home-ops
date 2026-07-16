{ lib, namespace, pkgs, ... }:

let
  localPackages = pkgs.${namespace};
  ibkrCli = localPackages."ibkr-cli";
  ibgatewayPackage = localPackages.ibgateway;

  ibkr = pkgs.writeShellApplication {
    name = "ibkr";
    runtimeInputs = [
      ibgatewayPackage
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
    ];
    text = ''
      export IBKR_UPSTREAM=${lib.escapeShellArg "${ibkrCli}/bin/ibkr"}
      ${builtins.readFile ./order-entry.sh}
      ${builtins.readFile ./ibkr-local.sh}
    '';
  };

  compatibility = pkgs.runCommand "ibkr-local-compat" { } ''
    mkdir -p "$out/bin"
    ln -s ${ibkr}/bin/ibkr "$out/bin/ibkr-local"
  '';
in
pkgs.symlinkJoin {
  name = "ibkr-local";
  paths = [
    ibkr
    compatibility
    ibgatewayPackage
  ];

  meta = {
    description = "Guarded local Interactive Brokers CLI and Gateway runtime";
    platforms = lib.platforms.linux;
  };
}
