{ pkgs, lib, config, ... }:
{
  config = lib.mkIf config.profiles.desktop.gnome.enable {
    environment.systemPackages = [
      pkgs.pcmanfm
    ];

    xdg = {
      mime.defaultApplications = {
        "inode/directory" = [ "pcmanfm.desktop" ];
      };
    };
  };
}
