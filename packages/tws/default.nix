{ pkgs, lib, ... }:

pkgs.symlinkJoin {
  name = "tws";

  paths = [
    (pkgs.writeShellApplication {
      name = "tws";
      runtimeInputs = [
        pkgs.podman
        pkgs.coreutils
        pkgs.gnused
      ];
      text = builtins.readFile ./wrapper.sh;
      runtimeEnv = {
        DOCKERFILE = ./Dockerfile;
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
