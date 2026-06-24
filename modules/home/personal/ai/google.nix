{ config, pkgs, lib, ... }:
lib.mkIf config.profiles.personal.enable {
  home.packages = with pkgs; [
    antigravity
    gws
    google-cloud-sdk
  ];

  programs.antigravity-cli = {
    enable = true;
  };
}
