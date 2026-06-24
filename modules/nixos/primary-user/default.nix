{ config, lib, pkgs, ... }:
{
  options = {
    primaryUser = lib.mkOption {
      type = lib.types.str;
      default = "xing";
    };
    features.primary-user.enable = lib.mkEnableOption "Enable primary user config";
  };

  config = lib.mkIf config.features.primary-user.enable {
    users.mutableUsers = true;

    users.users.${config.primaryUser} = {
      isNormalUser = true;
      home = "/home/${config.primaryUser}";
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;
      initialHashedPassword = "";
    };

    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ config.primaryUser ];
    };

    programs._1password.enable = true;

    users.users.root.initialHashedPassword = "";

    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
      execWheelOnly = true;
    };

    programs.zsh.enable = true;
  };
}
