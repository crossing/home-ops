{ config, pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  boot.initrd.luks = {
    reusePassphrases = true;
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
