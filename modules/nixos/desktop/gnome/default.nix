{ config, lib, pkgs, ... }:
{
  options = {
    profiles.desktop.gnome.enable = lib.mkEnableOption "Enable desktop profile.";
  };

  config = lib.mkIf config.profiles.desktop.enable {
    services.xserver.enable = true;
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;

    services.libinput.enable = true;

    xdg.portal = {
      enable = true;
      wlr.enable = true;
    };

    programs.dconf.enable = true;
    services.gnome = {
      gnome-browser-connector.enable = true;
      gnome-settings-daemon.enable = true;
    };

    environment.gnome.excludePackages = with pkgs; [
      gnome-music
      totem
    ];

    i18n.defaultLocale = "en_GB.UTF-8";
    i18n.inputMethod = {
      enable = true;
      type = "ibus";

      ibus.engines = with pkgs.ibus-engines; [ pinyin libpinyin typing-booster ];
    };

    programs.firefox.nativeMessagingHosts.packages = [
      pkgs.gnomeExtensions.gsconnect
    ];

    programs.kdeconnect.package = pkgs.gnomeExtensions.gsconnect;

    environment.systemPackages = with pkgs; [
      gnome-tweaks
      gnomeExtensions.dash-to-dock
    ];

    # https://github.com/NixOS/nixpkgs/issues/353588
    environment.variables = {
      GSK_RENDERER = "ngl";
    };
  };
}
