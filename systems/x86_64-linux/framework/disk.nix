{ lib, ... }:
{
  disko = {
    enableConfig = true;
    devices = {
      disk = {
        main = {
          type = "disk";
          device = "/dev/nvme0n1";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "crypt";
                  extraFormatArgs = [ "--type luks2" ];
                  content = {
                    type = "lvm_pv";
                    vg = "vg-system";
                  };
                };
              };
            };
          };
        };
      };
      lvm_vg = {
        "vg-system" = {
          type = "lvm_vg";
          lvs = {
            "nixos-root" = {
              size = "100%FREE";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
