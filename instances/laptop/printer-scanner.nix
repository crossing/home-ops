{ config, lib, pkgs, ... }:
{
  services.printing = {
    enable = true;
    drivers = [ pkgs.hplipWithPlugin ];
  };

  services.system-config-printer.enable = true;

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.hplipWithPlugin ];
  };

  services.avahi = {
    enable = true;
    nssmdns = true;
    reflector = true;
  };

  users.users.${config.primaryUser}.extraGroups = [ "scanner" "lp" ];
}
