{ config, lib, pkgs, ... }:
{
  options.profiles.personal = {
    enable = lib.mkEnableOption "personal profile settings";
  };

  imports = [
    ./home.nix
    ./zsh.nix
    ./ssh.nix
    ./desktop.nix
    ./secrets.nix
    ./nix.nix
    ./apps
    ./developer
    ./ai
  ];
}
