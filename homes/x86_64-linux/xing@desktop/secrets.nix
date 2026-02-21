{ config, ... }:
let
  secretsBase = ./../../../secrets/users/${config.home.username};
in
{
  sops.age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
  sops.secrets = {
    git_user_inc = {
      format = "yaml";
      sopsFile = secretsBase + "/git.yaml";
      path = "${config.xdg.configHome}/git/user.inc";
    };

  };
}
