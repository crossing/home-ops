{ pkgs, ... }:
{
  home.packages = [
    pkgs.antigravity
  ];

  programs.gemini-cli = {
    enable = true;
  };
}
