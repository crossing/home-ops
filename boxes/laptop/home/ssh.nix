{ config, pkgs, ... }:
{
  programs.ssh = {
    enable = true;
    compression = true;
    extraConfig = ''
      IdentityAgent = ~/.1password/agent.sock
    '';
  };
}
