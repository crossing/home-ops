{ config, pkgs, ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      compression = true;
      identityAgent = "~/.1password/agent.sock";
    };
  };
}
