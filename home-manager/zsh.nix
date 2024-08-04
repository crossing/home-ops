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

    initExtra = ''
      eval "$(${pkgs.python311Packages.argcomplete}/bin/register-python-argcomplete az)"
    '';

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
