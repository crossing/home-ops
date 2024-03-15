{ username, home }:
{ config, pkgs, lib, ... }:
{
  imports = [
    ./zsh.nix
    ./git.nix
    ./ssh.nix
    ./desktop.nix
    ./aws.nix
    ./secrets.nix
    ./rclone.nix
  ];

  fonts.fontconfig.enable = true;
  news.display = "silent";

  home.username = username;
  home.homeDirectory = home;
  home.language.base = "en_GB.UTF-8";
  home.sessionVariables = {
    NIX_PATH = "$HOME/.nix-defexpr/channels";
    EDITOR = "emacs";
  };

  home.packages = [
    # nix goodies
    pkgs.nixVersions.nix_2_19
    pkgs.niv
    pkgs.nix-tree
    pkgs.nixpkgs-fmt
    pkgs.nixos-generators
    pkgs.nix-doc

    # essential
    pkgs.chezmoi
    pkgs.zsh-completions

    # editors
    pkgs.emacs
    pkgs.vscode

    # utils
    pkgs.fasd
    pkgs.ripgrep
    pkgs.ranger
    pkgs.tree
    pkgs.killall
    pkgs.jq

    # cloud
    pkgs.azure-cli
    pkgs.google-cloud-sdk

    # ops
    pkgs.ansible
    pkgs.vagrant
    pkgs.terraform
    pkgs.tflint

    # k8s
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.kustomize
    pkgs.k9s
    pkgs.skaffold
    pkgs.minikube

    # python
    (pkgs.python3.withPackages (ps: with ps; [
      importmagic
      epc
      argcomplete
    ]))

    # rust
    pkgs.rustup

    # clojure
    pkgs.clojure
    pkgs.leiningen
    pkgs.clojure-lsp

    # misc
    pkgs.nodePackages.prettier
    pkgs.nodePackages.vscode-json-languageserver
    pkgs.nodePackages.pyright
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

  programs.nix-index.enable = true;

  services.lorri.enable = true;

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
