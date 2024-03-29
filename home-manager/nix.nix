{ pkgs, ... }:
let sources = import ./nix/sources.nix;
in
{
  home.packages = [
    pkgs.nixVersions.nix_2_20
    pkgs.niv
    pkgs.nix-tree
    pkgs.nixpkgs-fmt
    pkgs.nixos-generators
    pkgs.nix-doc
  ];

  programs.zsh.plugins = [
    {
      name = "zsh-nix-shell";
      file = "nix-shell.plugin.zsh";
      src = sources.zsh-nix-shell;
    }
  ];
}
