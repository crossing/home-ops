{ config, pkgs, lib, ... }:
{
    fonts.fontconfig.enable = lib.mkForce true;

  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "SourceCodePro" ]; })
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif

    libreoffice
  ];

  services.mpris-proxy.enable = true;
}
