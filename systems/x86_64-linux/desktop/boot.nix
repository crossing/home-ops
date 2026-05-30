{ config, pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    efi.canTouchEfiVariables = false;
  };

  boot.initrd.luks = {
    mitigateDMAAttacks = true;
    devices = {
      crypt = {
        device = "/dev/disk/by-uuid/a2b165c3-79cc-4c47-98cb-36ea7bee99bd";
        allowDiscards = true;
        preLVM = true;
      };
    };
  };
}
