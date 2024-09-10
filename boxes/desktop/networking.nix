{ ... }:
{
  networking = {
    hostName = "desktop";

    networkmanager.wifi = {
      powersave = false;
    };
  };
}
