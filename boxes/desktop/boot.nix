{ config, pkgs, ... }:
{
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_4;
  boot.kernelParams = [ "amdgpu.sg_display=0" ];

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
