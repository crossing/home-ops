{ config, pkgs, ... }:
{
  services.xserver = {
    enable = true;
    libinput.enable = true;

    # gnome
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;

    # keyboard
    layout = "gb,us";
    xkbVariant = "intl,altgr-intl";
  };

  programs.sway.enable = true;
  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  programs.dconf.enable = true;
  programs._1password-gui = {
    enable = true;
  };

  services.gnome = {
    gnome-browser-connector.enable = true;
    gnome-settings-daemon.enable = true;
  };

  environment.systemPackages = with pkgs; [
    gnome.gnome-tweaks
    gnomeExtensions.dash-to-dock
  ];

  environment.gnome.excludePackages = with pkgs; [
    gnome.gnome-music
    gnome.totem
  ];

  i18n.inputMethod.enabled = "ibus";
  i18n.inputMethod.ibus.engines = with pkgs.ibus-engines; [
    libpinyin
  ];

  programs.firefox = {
    enable = true;
    policies = {
      ExtensionSettings = {};
    };
    package = pkgs.firefox.override {
      cfg = {
        enableTridactylNative = true;
        enableGnomeExtensions = true;
      };
    };
  };
}
