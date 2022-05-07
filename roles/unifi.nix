{ config, lib, pkgs, ... }:
{
  networking.firewall = {
    enable = false;
  };

  services.unifi = {
    enable = true;
    unifiPackage = pkgs.unifi;
  };
}
