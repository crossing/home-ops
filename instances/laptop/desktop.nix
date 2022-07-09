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
  xdg.portal.wlr.enable = true;

  programs.dconf.enable = true;  
  programs._1password-gui = {
    enable = true;
    gid = 5000;
  };

  services.pipewire.enable = true;
  services.gnome = {
    chrome-gnome-shell.enable = true;
    gnome-settings-daemon.enable = true;
  };

  environment.gnome.excludePackages = with pkgs; [
    gnome.gnome-music
    gnome.totem
  ];

  i18n.inputMethod.enabled = "ibus";
  i18n.inputMethod.ibus.engines = with pkgs.ibus-engines; [
    libpinyin
  ];
}
