{ config, pkgs, ... }:
{
  users.mutableUsers = true;

  users.users.xing = {
    isNormalUser = true;
    home = "/home/xing";
    description = "Xing Yang";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.zsh;
    initialHashedPassword = "";
  };

  programs._1password-gui = {
    polkitPolicyOwners = [ "xing" ];
  };

  users.users.root.initialHashedPassword = "";

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
    execWheelOnly = true;
  };

  programs.zsh.enable = true;
}
