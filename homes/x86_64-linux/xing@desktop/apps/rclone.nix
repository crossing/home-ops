{ config, ... }:
{
  services.rcloneMounts = {
    enable = true;

    mounts = {
      google = {
        remote = "Drive";
        mountPoint = "${config.home.homeDirectory}/Documents/Google";
      };

      google-personal = {
        remote = "PersonalDrive";
        remotePath = "Para";
        mountPoint = "${config.home.homeDirectory}/Documents/GooglePersonal";
      };
    };
  };
}
