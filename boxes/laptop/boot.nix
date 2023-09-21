{ config, pkgs, ... }:
{
  boot.loader = {
    efi.efiSysMountPoint = "/boot/efi";

    grub = {
      enable = true;
      efiSupport = true;
      enableCryptodisk = true;
      device = "nodev";
      copyKernels = true;
      efiInstallAsRemovable = true;
    };
  };

  boot.initrd.luks = {
    reusePassphrases = true;
    mitigateDMAAttacks = true;
    devices = {
      crypt = {
        device = "/dev/disk/by-uuid/b31c643e-24b2-46b1-a2fa-4e9864b81b02";
        allowDiscards = true;
        preLVM = true;
      };
    };
  };
}
