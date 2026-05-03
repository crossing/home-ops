{ config, lib, pkgs, ... }:

let
  cfg = config.services.local-dns;
  # Helper to convert mappings to JSON for the python script
  mappingFile = pkgs.writeText "mac-mappings.json" (builtins.toJSON cfg.mappings);
  
  syncScript = pkgs.runCommand "sync-local-dns" { } ''
    mkdir -p $out/bin
    substitute ${./sync-local-dns.py} $out/bin/sync-local-dns \
      --subst-var-by arpScan ${pkgs.arp-scan}/bin/arp-scan \
      --subst-var-by ipCmd ${pkgs.iproute2}/bin/ip \
      --subst-var-by systemctl ${pkgs.systemd}/bin/systemctl
    chmod +x $out/bin/sync-local-dns
    patchShebangs $out/bin/sync-local-dns
  '';
in
{
  options.services.local-dns = {
    enable = lib.mkEnableOption "local-dns service";
    mappings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "MAC address to friendly name mappings";
    };
  };

  config = lib.mkIf cfg.enable {
    # CoreDNS configuration
    services.coredns = {
      enable = true;
      config = ''
        . {
            health :8081
            ready :8081
            hosts /var/lib/local-dns/coredns.hosts home.local {
                fallthrough
            }
            # Proxy to Cloudflare and local gateway
            forward . 1.1.1.1 1.0.0.1 192.168.1.1
            cache 3600
            reload
            log
            errors
        }
      '';
    };

    # Avahi configuration
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    # Symlink Avahi hosts to the dynamic file
    environment.etc."avahi/hosts".source = "/var/lib/local-dns/avahi-hosts";

    # Ensure directory and initial files exist
    systemd.tmpfiles.rules = [
      "d /var/lib/local-dns 0755 root root -"
      "f /var/lib/local-dns/coredns.hosts 0644 root root -"
      "f /var/lib/local-dns/avahi-hosts 0644 root root -"
    ];

    # Systemd service for the sync script
    systemd.services.sync-local-dns = {
      description = "Sync MAC mappings to local DNS";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${syncScript}/bin/sync-local-dns";
        Environment = [ "MAPPINGS_FILE=${mappingFile}" ];
      };
      path = [ pkgs.python3 pkgs.arp-scan pkgs.iproute2 pkgs.systemd ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    # Timer to run every minute
    systemd.timers.sync-local-dns = {
      description = "Run sync-local-dns every minute";
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "1m";
      };
      wantedBy = [ "timers.target" ];
    };

    # Firewall settings
    networking.firewall.allowedUDPPorts = [ 53 5353 ];
    networking.firewall.allowedTCPPorts = [ 53 ];
    
    # Required system packages
    environment.systemPackages = [ pkgs.arp-scan ];
  };
}
