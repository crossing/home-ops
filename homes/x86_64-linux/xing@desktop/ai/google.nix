{ pkgs, ... }:
{
  home.packages = with pkgs; [
    antigravity
    gws
    google-cloud-sdk
  ];

  programs.gemini-cli = {
    enable = true;
  };
}
