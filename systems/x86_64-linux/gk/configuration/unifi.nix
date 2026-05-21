{ config, lib, pkgs, inputs, ... }:
{
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.unifi = {
      image = "unifi-os-server:5.0.8";
      imageFile = inputs.self.packages.${pkgs.system}.unifi-os-server;
      # Capabilities and systemd compatibility options for running UniFi OS Server in Docker unprivileged
      extraOptions = [
        "--cgroupns=host"
        "--cap-add=SYS_ADMIN"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        "--cap-add=NET_BIND_SERVICE"
        "--cap-add=DAC_OVERRIDE"
        "--cap-add=DAC_READ_SEARCH"
        "--cap-add=FOWNER"
        "--cap-add=CHOWN"
        "--cap-add=SETUID"
        "--cap-add=SETGID"
        "--cap-add=KILL"
        "--cap-add=SYS_CHROOT"
        "--cap-add=SYS_PTRACE"
        "--cap-add=SYS_RESOURCE"
        "--cap-add=AUDIT_WRITE"
        "--cap-add=MKNOD"
        "--tmpfs=/run:exec"
        "--tmpfs=/run/lock"
        "--tmpfs=/tmp:exec"
        "--tmpfs=/var/lib/journal"
        "--tmpfs=/var/opt/unifi/tmp:size=64m"
        "--network=host"
      ];
      volumes = [
        "/sys/fs/cgroup:/sys/fs/cgroup:rw"
        "/var/lib/unifi:/unifi"
      ];
    };
  };

  # Open UniFi network controller ports in the firewall
  networking.firewall.allowedTCPPorts = [
    8080 # Port for UAP to inform controller
    443  # Port for UniFi OS HTTPS portal
    8880 # Port for HTTP portal redirect
    8843 # Port for HTTPS portal redirect
    6789 # Port for UniFi mobile speed test
  ];
  networking.firewall.allowedUDPPorts = [
    3478  # UDP port for STUN
    10001 # UDP port for AP discovery
    10003 # UDP port for AP discovery/inform
    1900  # UDP port for UPnP discovery
  ];
}
