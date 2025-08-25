{ config, lib, ... }:
{
  options = {
    profiles.desktop.audio.enable = lib.mkEnableOption "Enable audio profile.";
  };

  config =
    let
      cfg = config.profiles.desktop;
    in
    lib.mkIf cfg.audio.enable {
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        wireplumber.enable = true;
      };
    };
}
