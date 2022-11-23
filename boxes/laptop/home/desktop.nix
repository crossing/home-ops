{ config, pkgs, lib, ... }:
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox.override {
      cfg = {
        enableTridactylNative = true;
        enableGnomeExtensions = true;
      };
    };
  };

  fonts.fontconfig.enable = lib.mkForce true;

  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "SourceCodePro" ]; })
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif

    libreoffice
  ];
}
