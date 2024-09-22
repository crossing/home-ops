{ config, pkgs, lib, ... }:
let
  sources = import ./nix/sources.nix;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    autocd = true;

    shellAliases = {
      j = "z";
      jj = "zz";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "git-extras"
        "docker"
        "ansible"
        "kubectl"
        "helm"
        "fasd"
        "python"
        "pip"
        "terraform"
        "vagrant"
      ];
    };
  };
}
