{ inputs, lib, ... }:
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"
  ];

  # Enable SSH for nixos-anywhere provisioning
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkForce "yes";
  };

  # Ensure Wi-Fi is enabled (wpa_supplicant) along with DHCP for network installation
  networking.wireless.enable = true;
  networking.useDHCP = lib.mkForce true;
}
