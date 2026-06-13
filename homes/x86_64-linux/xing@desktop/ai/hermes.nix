{ pkgs, ... }:
{
  home.packages = [
    pkgs.hermes-agent
    pkgs.hermes-desktop
  ];
}
