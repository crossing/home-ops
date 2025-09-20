{ config, pkgs, ... }:
{
  services.xserver = {
    # keyboard
    xkb = {
      layout = "us";
      variant = "altgr-intl";
    };
  };

  programs._1password-gui = {
    enable = true;
  };

  programs.firefox = {
    enable = true;
    policies = {
      ExtensionSettings = { };
    };
    nativeMessagingHosts = {
      packages = [
        pkgs.tridactyl-native
      ];
    };
  };

  programs.kdeconnect.enable = true;

  environment.systemPackages = with pkgs; [
    (google-chrome.override {
      commandLineArgs = [
        "--enable-webrtc-pipewire-capturer"
        "--gtk-version=4"
      ];
    })
  ];
}
