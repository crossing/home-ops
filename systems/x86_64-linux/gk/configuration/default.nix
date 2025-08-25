{ config, lib, pkgs, ... }:
{
  services.unifi = {
    enable = true;
    openFirewall = true;
    unifiPackage = pkgs.unifi;
    mongodbPackage = pkgs.mongodb-7_0;
  };

  networking.firewall.allowedTCPPorts = [
    8443
  ];

  systemd.services.unifi.serviceConfig = {
    RuntimeMaxSec = 24 * 3600;
    Restart = lib.mkForce "always";
  };
}
