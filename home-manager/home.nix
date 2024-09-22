{ config, pkgs, lib, ... }:
{
  fonts.fontconfig.enable = true;
  news.display = "silent";

  home.language.base = "en_GB.UTF-8";
  home.sessionVariables = {
    NIX_PATH = "$HOME/.nix-defexpr/channels";
  };

  home.packages = [
    # editors
    pkgs.vscode

    # utils
    pkgs.fasd
    pkgs.ripgrep
    pkgs.ranger
    pkgs.tree
    pkgs.killall
    pkgs.jq

    # k8s
    pkgs.kubectl
    pkgs.k9s
    pkgs.minikube

    # python
    (pkgs.python311.withPackages (ps: with ps; [
      importmagic
      epc
    ]))

    # clojure
    pkgs.clojure
    pkgs.leiningen
    pkgs.clojure-lsp

    # misc
    pkgs.nodePackages.prettier
    pkgs.nodePackages.vscode-json-languageserver
    pkgs.pyright

    # apps
    pkgs.jabref
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    settings = lib.importTOML ./files/starship.toml;
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "21.11";
}
