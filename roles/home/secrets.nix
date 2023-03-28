{ config, ... }:
{
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  sops.secrets = {
    git_user_inc = {
      format = "yaml";
      sopsFile = ./secrets/git.yaml;
      path = "${config.home.homeDirectory}/.config/git/user.inc";
    };

    "rclone.conf" = {
      format = "binary";
      sopsFile = ./secrets/rclone.conf;
      path = "${config.home.homeDirectory}/.config/rclone/rclone.conf";
    };
  };
}
