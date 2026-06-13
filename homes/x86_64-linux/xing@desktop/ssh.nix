{ config, pkgs, ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      compression = true;
      identityAgent = "~/.1password/agent.sock";
    };
  };
}
