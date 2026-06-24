{ config, lib, pkgs, ... }:
{
  options.features.printer-scanner.enable = lib.mkEnableOption "Enable printer and scanner configuration";

  config = lib.mkIf config.features.printer-scanner.enable {
    # Enable CUPS to print documents.
    services.printing.enable = true;

    # Enable SANE scanning
    hardware.sane = {
      enable = true;
      extraBackends = [ pkgs.hplipWithPlugin ];
    };

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    users.users.${config.primaryUser}.extraGroups = [ "scanner" "lp" ];
  };
}
