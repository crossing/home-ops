{ ... }:
{
  networking = {
    hostName = "framework";

    networkmanager = {
      wifi.powersave = true;
      # Use dnsmasq for DNS resolution
      dns = "dnsmasq";
    };
  };

  # Disable systemd-resolved to let dnsmasq handle things
  services.resolved.enable = false;

  # Configure dnsmasq for split DNS
  environment.etc."NetworkManager/dnsmasq.d/home-local.conf".text = ''
    # Route home.local queries to the gk server
    server=/home.local/192.168.1.3
    log-queries
  '';
}
