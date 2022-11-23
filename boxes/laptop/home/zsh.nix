{ config, pkgs, lib, ... }:
let sources = import ./nix/sources.nix;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    enableSyntaxHighlighting = true;
    autocd = true;

    initExtra = ''
      eval "$(register-python-argcomplete az)"
      eval "$(register-python-argcomplete gcloud)"
    '';

    initExtraBeforeCompInit = ''
      source $HOME/.zshrc.legacy
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
        "emacs"
      ];
    };

    plugins = [

      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = sources.zsh-nix-shell;
      }
    ];
  };
}
