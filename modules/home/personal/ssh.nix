{ config, pkgs, lib, ... }:
lib.mkIf config.profiles.personal.enable {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      compression = true;
      identityAgent = "~/.1password/agent.sock";
    };
  };
}
