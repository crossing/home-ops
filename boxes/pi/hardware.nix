{ ... }:
{
  boot.loader {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
    raspberryPi = {
      enable = true;
      version = 3;
      uboot.enable = true;
    };
  };

  disko = {
    enableConfig = true;
    devices.disk = {
      sdcard = {
        type = "disk";
        device = "/dev/mmcblk0";
        content = {
          type = "table";
          format = "msdos";
          partitions = [
            {
              name = "boot";
              start = "1M";
              end = "512M";
              part-type = "primary";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            }
            {
              name = "root";
              start = "513M";
              end = "100%";
              content = {
                type = "filesystem";
                format = "f2fs";
                mountpoint = "/";
              };
            }
          ];
        };
      };
    };
  };
}
