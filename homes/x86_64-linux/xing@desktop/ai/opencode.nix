{ pkgs, ... }:
{
  home.packages = with pkgs; [ oh-my-opencode ];
  programs.opencode.enable = true;
}
