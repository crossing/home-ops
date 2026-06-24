{ config, pkgs, lib, ... }:
lib.mkIf config.profiles.personal.enable {
  home.packages = [
    pkgs.hermes-agent
    pkgs.hermes-desktop
  ];
}
