{ config, lib, ... }:
{
  options = {
    profiles.desktop.enable = lib.mkEnableOption "Enable desktop profile.";
  };

  config = lib.mkIf config.profiles.desktop.enable {
    profiles.desktop.audio.enable = lib.mkDefault true;
    profiles.desktop.gnome.enable = lib.mkDefault true;
  };
}
