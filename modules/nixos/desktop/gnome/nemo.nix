{ pkgs, lib, config, ... }:
{
  config = lib.mkIf config.profiles.desktop.gnome.enable {
    environment.systemPackages = [
      pkgs.nemo-with-extensions
    ];

    xdg = {
      mime.defaultApplications = {
        "inode/directory" = [ "nemo.desktop" ];
        "application/x-gnome-saved-search" = [ "nemo.desktop" ];
      };
    };
  };
}
