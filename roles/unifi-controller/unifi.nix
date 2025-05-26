{ config, lib, pkgs, ... }:
let
  cfg = config.services.unifi;
in
{
  options = {
    services.unifi.dailyReboot = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = {
    services.unifi = {
      enable = true;
      openFirewall = true;
      unifiPackage = pkgs.unifi;
      mongodbPackage = pkgs.mongodb-7_0;
    };

    networking.firewall.allowedTCPPorts = [
      8443
    ];

    systemd.services.unifi.serviceConfig = lib.mkIf cfg.dailyReboot {
      RuntimeMaxSec = 24 * 3600;
      Restart = lib.mkForce "always";
    };
  };
}
