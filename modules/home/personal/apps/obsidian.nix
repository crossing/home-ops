{ config, pkgs, lib, ... }:
lib.mkIf config.profiles.personal.enable {
  home.packages = [
    pkgs.obsidian
  ];
}
