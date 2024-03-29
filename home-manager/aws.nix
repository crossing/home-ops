{ pkgs, ... }:
let sources = import ./nix/sources.nix;
in
{
  home.packages = with pkgs; [
    aws-vault
    awscli2
  ];

  programs.zsh = {
    oh-my-zsh.plugins = [
      "aws"
    ];

    plugins = [
      {
        name = "zsh-aws-vault";
        src = sources.zsh-aws-vault;
      }
    ];
  };
}
