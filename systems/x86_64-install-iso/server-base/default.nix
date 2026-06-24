{ lib, ... }:
{
  profiles.server.enable = true;

  # Ensure Wi-Fi is enabled (wpa_supplicant) along with DHCP for network installation
  networking.wireless.enable = true;
  networking.useDHCP = lib.mkForce true;
}
