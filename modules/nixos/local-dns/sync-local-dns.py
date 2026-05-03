#!/usr/bin/env python3
import json
import subprocess
import os
import sys
import socket

# These will be substituted by Nix
ARP_SCAN = "@arpScan@"
IP_CMD = "@ipCmd@"
SYSTEMCTL = "@systemctl@"
MAPPINGS_FILE = os.environ.get("MAPPINGS_FILE")
COREDNS_HOSTS = "/var/lib/local-dns/coredns.hosts"
AVAHI_HOSTS = "/var/lib/local-dns/avahi-hosts"

def get_hostname(ip):
    try:
        # socket.gethostbyaddr uses the system resolver.
        # Since gk uses Unifi Gateway (192.168.1.1) as its upstream DNS,
        # it should be able to resolve names from the Unifi DHCP leases.
        name = socket.gethostbyaddr(ip)[0]
        # Strip domain if it's there (e.g. NPIDAAAE2.home.internal -> NPIDAAAE2)
        return name.split('.')[0]
    except Exception:
        return None

def main():
    if not MAPPINGS_FILE:
        print("MAPPINGS_FILE env var not set")
        sys.exit(1)

    try:
        with open(MAPPINGS_FILE, 'r') as f:
            mappings = {k.lower(): v for k, v in json.load(f).items()}
    except Exception as e:
        print(f"Error loading mappings: {e}")
        sys.exit(1)

    discovered_macs = {} # mac -> ip
    discovered_ips = {}  # ip -> mac

    # 1. Get local interfaces IPs/MACs
    try:
        ip_result = subprocess.run([IP_CMD, '-j', 'link'], capture_output=True, text=True, check=True)
        links = json.loads(ip_result.stdout)
        for link in links:
            if 'address' in link:
                mac = link['address'].lower()
                addr_result = subprocess.run([IP_CMD, '-j', 'addr', 'show', link['ifname']], capture_output=True, text=True, check=True)
                addrs = json.loads(addr_result.stdout)
                for addr in addrs:
                    for addr_info in addr.get('addr_info', []):
                        if addr_info.get('family') == 'inet':
                            ip = addr_info['local']
                            discovered_macs[mac] = ip
                            discovered_ips[ip] = mac
    except Exception as e:
        print(f"Error getting local interface info: {e}")

    # 2. Run arp-scan to find everything on the network
    try:
        # Increased timeout and retry to be more reliable
        result = subprocess.run(
            [ARP_SCAN, '--localnet', '-q', '-t', '1000', '-r', '2'],
            capture_output=True, text=True, check=True
        )
        for line in result.stdout.splitlines():
            parts = line.split('\t')
            if len(parts) >= 2:
                ip = parts[0]
                mac = parts[1].lower()
                discovered_macs[mac] = ip
                discovered_ips[ip] = mac
    except Exception as e:
        print(f"Error running arp-scan: {e}")

    # 3. Check ARP cache for any other missed devices
    try:
        neigh_result = subprocess.run([IP_CMD, '-j', 'neigh', 'show'], capture_output=True, text=True, check=True)
        neighbors = json.loads(neigh_result.stdout)
        for n in neighbors:
            if n.get('state') != ['FAILED'] and 'lladdr' in n and 'dst' in n:
                mac = n['lladdr'].lower()
                ip = n['dst']
                if mac not in discovered_macs:
                    discovered_macs[mac] = ip
                if ip not in discovered_ips:
                    discovered_ips[ip] = mac
    except Exception as e:
        print(f"Error reading ARP cache: {e}")

    coredns_entries = {} # name -> ip
    avahi_entries = {}   # name -> ip

    def add_entry(name, ip):
        # Sanitize name
        safe_name = "".join(c for c in name if c.isalnum() or c == '-')
        if not safe_name: return
        
        # Lowercase for consistency
        safe_name = safe_name.lower()
        
        if safe_name not in coredns_entries:
            coredns_entries[safe_name] = ip
        if safe_name not in avahi_entries:
            avahi_entries[safe_name] = ip

    # 4. Process all discovered devices
    for mac, ip in discovered_macs.items():
        # Always add fallback dev-<mac>
        clean_mac = mac.replace(":", "")
        add_entry(f"dev-{clean_mac}", ip)
        
        # Add friendly name if mapped
        friendly_name = mappings.get(mac)
        if friendly_name:
            add_entry(friendly_name, ip)
            
        # Add discovered hostname
        hostname = get_hostname(ip)
        if hostname and hostname not in ['localhost', 'gk']:
            add_entry(hostname, ip)

    # 5. Ensure all mapped devices are present if we found them
    # (Already handled by the loop above, but this confirms we didn't miss a mapping)

    def write_if_changed(path, entries, suffix):
        lines = []
        for name, ip in sorted(entries.items()):
            lines.append(f"{ip} {name}{suffix}")
        
        new_content = '\n'.join(lines) + '\n'
        old_content = ""
        if os.path.exists(path):
            with open(path, 'r') as f:
                old_content = f.read()
        
        if old_content != new_content:
            with open(path + ".tmp", 'w') as f:
                f.write(new_content)
            os.replace(path + ".tmp", path)
            return True
        return False

    changed_coredns = write_if_changed(COREDNS_HOSTS, coredns_entries, ".home.local")
    changed_avahi = write_if_changed(AVAHI_HOSTS, avahi_entries, ".local")

    if changed_coredns:
        print("Reloading coredns...")
        subprocess.run([SYSTEMCTL, 'reload', 'coredns'])
    
    if changed_avahi:
        print("Restarting avahi-daemon...")
        subprocess.run([SYSTEMCTL, 'restart', 'avahi-daemon'])

if __name__ == "__main__":
    main()
