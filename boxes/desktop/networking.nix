{ ... }:
{
  networking = {
    hostName = "desktop";

    networkmanager.wifi = {
      powersave = false;
      backend = "iwd";
    };
  };
}
