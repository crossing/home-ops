{ config, pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    efi.canTouchEfiVariables = true;
  };

  boot.initrd.luks = {
    mitigateDMAAttacks = true;
    devices = {
      crypt = {
        device = "/dev/disk/by-uuid/CHANGE_ME_LUKS_UUID";
        allowDiscards = true;
        preLVM = true;
      };
    };
  };
}
