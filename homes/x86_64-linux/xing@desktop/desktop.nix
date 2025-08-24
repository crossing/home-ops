{ config, pkgs, lib, ... }:
{
  fonts.fontconfig.enable = lib.mkForce true;

  home.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.sauce-code-pro
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif

    libreoffice
  ];

  services.mpris-proxy.enable = true;
}
