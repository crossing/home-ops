{ pkgs, ... }:
let sources = import ./nix/sources.nix;
in
{
  home.packages = with pkgs; [
    aws-vault
    awscli2
  ];

  home.file.".aws/config" = {
    source = ./files/aws-config;
  };

  programs.zsh = {
    oh-my-zsh.plugins = [ "aws" ];

    plugins = [
      {
        name = "zsh-aws-vault";
        src = sources.zsh-aws-vault;
      }
    ];
  };
}
