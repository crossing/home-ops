{ pkgs, ... }:
{
  home.packages = with pkgs; [
    antigravity
    gws
    google-cloud-sdk
  ];

  programs.antigravity-cli = {
    enable = true;
  };
}
