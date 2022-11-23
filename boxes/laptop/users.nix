{ config, lib, pkgs, ... }:
{
  options.primaryUser = lib.mkOption {
    type = lib.types.str;
  };

  config = {
    primaryUser = "xing";
    users.mutableUsers = true;

    users.users.${config.primaryUser} = {
      isNormalUser = true;
      home = "/home/${config.primaryUser}";
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;
      initialHashedPassword = "";
    };

    programs._1password-gui = {
      polkitPolicyOwners = [ config.primaryUser ];
    };

    users.users.root.initialHashedPassword = "";

    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
      execWheelOnly = true;
    };

    programs.zsh.enable = true;
  };
}
