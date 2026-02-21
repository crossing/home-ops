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
        mountPoint = "${config.home.homeDirectory}/Documents/GooglePersonal";
      };
    };
  };
}
