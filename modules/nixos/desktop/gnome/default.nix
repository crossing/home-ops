{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./pcmanfm.nix
    inputs.xdp-termfilepickers.nixosModules.default
  ];

  options = {
    profiles.desktop.gnome.enable = lib.mkEnableOption "Enable desktop profile.";
  };

  config = lib.mkIf config.profiles.desktop.enable {
    services.xserver.enable = true;
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;

    services.libinput.enable = true;

    services.xdg-desktop-portal-termfilepickers = {
      enable = true;
      package = inputs.xdp-termfilepickers.packages.${pkgs.system}.default;
      config = {
        terminal_command = [ (lib.getExe pkgs.kitty) "--title" "filepicker" "-e" ];
      };
    };

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;

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
      nautilus
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
      kitty
      yazi
      nushell
    ];
  };
}
