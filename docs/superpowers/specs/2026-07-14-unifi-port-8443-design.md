# UniFi OS Server Port 8443 Design

## Goal

Publish the `gk` UniFi OS Server HTTPS interface on TCP port 8443 instead of
11443 without changing the reusable module default or its VM-test port.

## Design

Change only `services.unifi-os-server.webPort` in
`systems/x86_64-linux/gk/configuration/unifi.nix`. The existing NixOS module
will map host TCP 8443 to container TCP 443 and open the selected host port in
the firewall. No container data, UniFi application settings, or backup files
are modified.

## Deployment and rollback

Build the complete `gk` system before activation. Deploy through the existing
NixOS workflow, retaining the currently working generation as the rollback
target. If HTTPS fails on 8443, the service is unhealthy, or 11443 remains
published, activate the previous generation and re-check the original 11443
endpoint.

## Acceptance criteria

- The `gk` NixOS build and UniFi VM regression pass.
- `unifi-os-server.service` is active after activation with no restart loop.
- HTTPS responds on `https://192.168.1.3:8443/`.
- TCP 11443 is no longer listening.
- TCP 27017 remains unexposed on the host.
- The three restored UniFi devices remain present and reachable.
- Only after these checks pass is the branch merged into `master`.
