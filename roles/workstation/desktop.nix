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

  environment.gnome.excludePackages = with pkgs; [
    gnome.gnome-music
    gnome.totem
  ];

  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.inputMethod.enabled = "fcitx5";
  i18n.inputMethod.fcitx5.addons = with pkgs; [
    fcitx5-chinese-addons
    fcitx5-rime
  ];

  programs.firefox = {
    enable = true;
    policies = {
      ExtensionSettings = { };
    };
    nativeMessagingHosts = {
      packages = with pkgs; [
        tridactyl-native
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    (google-chrome.override {
      commandLineArgs = "--enable-webrtc-pipewire-capturer";
    })
    gnome.gnome-tweaks
    gnomeExtensions.dash-to-dock
  ];
}
