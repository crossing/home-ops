{ config, lib, pkgs, ... }:
{
  services.unifi = {
    enable = true;
    openFirewall = true;
    unifiPackage = pkgs.unifi;
  };

  networking.firewall.allowedTCPPorts = [
    8443
  ];
}
