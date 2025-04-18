{ config, pkgs, ... }:
{
  services.xserver = {
    enable = true;

    # gnome
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;

    # keyboard
    xkb = {
      layout = "gb,us";
      variant = "intl,altgr-intl";
    };
  };

  services.libinput.enable = true;

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

  programs.firefox = {
    enable = true;
    policies = {
      ExtensionSettings = { };
    };
    nativeMessagingHosts = {
      packages = with pkgs; [
        tridactyl-native
        gnomeExtensions.gsconnect
      ];
    };
  };

  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  environment.systemPackages = with pkgs; [
    (google-chrome.override {
      commandLineArgs = [
        "--enable-webrtc-pipewire-capturer"
        "--gtk-version=4"
      ];
    })
    gnome-tweaks
    gnomeExtensions.dash-to-dock
  ];

  # https://github.com/NixOS/nixpkgs/issues/353588
  environment.variables = {
    GSK_RENDERER = "gl";
  };
}
