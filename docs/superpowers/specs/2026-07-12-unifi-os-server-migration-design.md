# UniFi OS Server Migration Design

## Purpose

Migrate `gk` from the legacy NixOS `services.unifi` deployment to Ubiquiti's supported Linux UniFi OS Server architecture. Preserve a deterministic rollback to the current controller if installation, data migration, device adoption, or post-reboot operation fails.

This design replaces the repository's unsupported Docker configuration. The official installer remains the release artifact and source of truth, but Nix reproduces its observed rootless Podman contract so host state remains declarative and generation rollback remains reliable.

## Observed Baseline

The live host was inspected read-only on 2026-07-12:

- Host: `gk`, NixOS 25.11, x86-64 Intel Celeron J4105, address `192.168.1.3/24`.
- Active controller: `unifi.service`, UniFi Network 10.2.105.
- Database: MongoDB 7.0.25 from the Nix store, started as a child of UniFi.
- Persistent legacy data: `/var/lib/unifi`, approximately 526 MiB.
- Latest observed automatic backup: `autobackup_10.2.105_20260701_0030_1782865800007.unf`.
- Capacity: approximately 202 GiB free disk and 6.1 GiB available RAM.
- Swap: none.
- Container runtime: Docker and Podman are not active in the deployed generation.
- Rollback point: NixOS system generation 15, dated 2026-05-10.
- Hardware virtualization is available through `/dev/kvm`.
- The CPU does not expose AVX.

The repository already contains an undeployed `unifi-os-server:5.0.8` Docker configuration. It must not be deployed as the migration target.

## Non-AVX Compatibility Evidence

The official UniFi OS Server 5.1.15 Linux x64 installer was downloaded from Ubiquiti and its embedded OCI image was inspected without installing it. The image bundles Ubiquiti's MongoDB 3.6.23 build (`git version 7e9159ff564980384f9703a7104074f6e36cd611`) at `/usr/bin/mongod`, not an upstream MongoDB 5.0-or-newer binary.

The exact bundled executable and its container libraries were copied temporarily to `gk`. With `/proc/cpuinfo` confirming that AVX is absent, two probes passed:

1. `mongod --version` exited successfully and reported version 3.6.23.
2. A temporary MongoDB instance using an empty database under `/tmp` initialized WiredTiger, listened on localhost TCP 27119, received SIGTERM after eight seconds, and shut down cleanly with code 0.

The same executable also completed the version probe under QEMU emulating a pre-AVX Westmere CPU. These results establish that the MongoDB bundled with UniFi OS Server 5.1.15 does not require AVX for startup or normal storage-engine initialization on `gk`.

Because the implementation will pin the newest suitable stable release rather than assume all future images retain this binary, the implementation plan must repeat the extraction and on-host startup probe against the exact selected installer before live cutover. An installer whose MongoDB probe exits with `SIGILL`, fails before listening, or bundles an upstream AVX-dependent MongoDB release fails the feasibility gate.

## Selected Architecture

NixOS owns the complete host-side runtime. The official installer is kept untouched and pinned by version, URL, and SHA-256; Nix extracts its embedded OCI archive and independently pins the archive's image reference and immutable image ID.

The disabled-by-default NixOS module provides:

- Rootless Podman with the installer-supported `pasta` networking backend.
- A dedicated `uosserver` system account with subordinate UID/GID ranges.
- A stable per-install UUID stored outside the Nix store with mode `0600`.
- Seven named Podman volumes matching the observed installer persistence boundaries.
- The exact 5.1.21 container capabilities, environment, mounts, and port mappings.
- A systemd preparation unit that verifies the loaded image ID and idempotently creates volumes.
- A foreground systemd service that owns container replacement, graceful shutdown, and HTTPS readiness.
- At least 2 GiB of swap and firewall rules derived from the pinned release and Ubiquiti's port reference.

The vendor updater service is deliberately omitted. Upgrades occur by changing `source.json`, repeating the non-AVX and VM lifecycle gates, and deploying a new NixOS generation. This prevents an in-application update from replacing declarative host state.

## Feasibility Gate

Before changing `gk`, reproduce its relevant NixOS configuration in a disposable KVM-accelerated NixOS VM and run the declarative service with the image extracted from the pinned official installer.

The feasibility test must prove:

1. The official OCI archive extracts and loads with only declared dependencies.
2. The loaded image reference and ID exactly match the release metadata.
3. The rootless Podman container reaches healthy state.
4. Required ports bind successfully.
5. UniFi OS Server survives a guest reboot.
6. Container recreation preserves all named volumes.
7. Switching back to the pre-install VM generation disables the new runtime without requiring destructive cleanup.

The installer-created files, units, mounts, and port maps were inventoried in a disposable VM before this architecture was selected. Any host mutation that conflicts with NixOS ownership is converted into declarative configuration or isolated under `/var/lib/uosserver`. Failure of any gate stops the live migration and leaves the legacy service unchanged.

## Data Protection and Migration

The old and new systems must use separate persistence roots. The new server must never mount the legacy `/var/lib/unifi` directory directly.

Immediately before cutover:

1. Generate and download a fresh Network-only `.unf` backup from the legacy controller.
2. Copy that backup to a second machine and verify its SHA-256 after transfer.
3. Record the legacy Network version, site count, device inventory, controller address, and device online state.
4. Stop `unifi.service` cleanly and verify both Java and MongoDB have exited.
5. Create a cold archive or filesystem snapshot of `/var/lib/unifi`, preserving ownership, permissions, ACLs, and timestamps.
6. Copy the cold archive off-host and verify its checksum.
7. Record system generation 15 and ensure it remains bootable and present in the system profile.

After the cold copy is complete, deploy the prepared NixOS generation. Attempt migration in this order:

1. Restore the fresh `.unf` backup through UniFi OS Server.
2. Use Ubiquiti's Site Export and Import workflow if backup restoration cannot preserve the deployment cleanly.

Do not factory-reset or forget any managed device merely to make the first migration attempt succeed. Such actions would weaken rollback and require separate approval.

## Network and Firewall

The new server will replace the old controller on the same host and address, `192.168.1.3`. Because controller downtime is acceptable, the old and new runtimes do not need to coexist or bind alternate production ports.

The implementation must compare the pinned release's actual Podman port mappings with Ubiquiti's port documentation. UniFi OS Server 5.1.x differs from the legacy service, including captive portal TCP 8444 instead of TCP 8843. The observed 5.1.15 runtime also maps TCP 9543, 28082, 5671, 6789, 8080, 8444, 8880, 8881, 8882, and 11443; UDP 3478, 5514, and 10003; and loopback-only TCP 11084. Only ports required from the LAN should be opened in the NixOS firewall.

The legacy firewall rules must not remain merely for compatibility. Each retained port must have a documented consumer and exposure scope.

## Cutover Acceptance Tests

The migration succeeds only when all applicable checks pass:

- UniFi OS Server and its Podman container are healthy.
- Local administrator login works and ownership is correct.
- Every expected site appears.
- Device inventory matches the recorded baseline.
- All previously online devices return online without factory reset.
- Devices send inform traffic successfully to TCP 8080.
- STUN and discovery traffic work where used.
- A harmless configuration change can be provisioned to one selected test device and reverted.
- The UI, topology, client list, events, and historical configuration are usable.
- A new backup can be created and downloaded from the new server.
- The host and controller survive one controlled reboot.
- CPU, memory, swap, disk, and logs show no sustained resource exhaustion or restart loop.
- Remote management is either deliberately configured and verified or deliberately left disabled.

After the reboot test, retain the old data and rollback generation through a minimum seven-day soak period. During that period, monitor service health, device connectivity, backups, disk growth, and update behavior.

## Rollback

Rollback is triggered by failed migration, missing sites or devices, ownership problems, repeated service restarts, inability to provision, unacceptable resource pressure, or failure after reboot.

Rollback procedure:

1. Stop and disable UniFi OS Server and confirm its Podman container no longer binds controller ports.
2. Switch or boot back to system generation 15, which contains `unifi.service`, UniFi Network 10.2.105, and MongoDB 7.0.25.
3. If `/var/lib/unifi` remained untouched, start `unifi.service` directly. If it changed, replace it with the verified cold archive while the service is stopped.
4. Verify Java, MongoDB, and the legacy HTTPS endpoint are healthy.
5. Verify the recorded sites and devices reconnect and that inform traffic resumes.
6. Preserve the failed OS Server state for diagnosis; do not uninstall or delete its volumes during the outage response.

The rollback target is the exact legacy application and database pair, not a downgrade or import from the new server. No data created exclusively after cutover is expected to be portable back to the legacy controller; this is why the acceptance window should be short and configuration changes minimized until the reboot test passes.

## Cleanup

After at least seven stable days and a verified UniFi OS Server backup:

- Remove the unsupported standalone Docker image package and container definition from the repository.
- Remove legacy UniFi Network service configuration and its insecure MongoDB dependency if any remains on the deployed host.
- Retain one encrypted off-host `.unf` backup and the cold legacy archive according to the user's backup policy.
- Remove obsolete firewall rules.
- Garbage-collect the old Nix closure only after explicitly deciding that generation-15 rollback is no longer required.

## Out of Scope

- Factory-resetting or manually re-adopting devices during the initial migration.
- Migrating UniFi Protect, Access, Talk, or Connect; UniFi OS Server self-hosts Network and supported OS features, not those console-only applications.
- Enabling remote cloud access without an explicit decision.
- Deleting legacy data or Nix generations before the soak period is complete.

## References

- [Ubiquiti: Self-Hosting UniFi](https://help.ui.com/hc/en-us/articles/34210126298775-Self-Hosting-UniFi)
- [Ubiquiti: Backups and Migration in UniFi](https://help.ui.com/hc/en-us/articles/360008976393-Backups-and-Migration-in-UniFi)
- [Ubiquiti: UniFi OS Server releases](https://www.ui.com/download/releases/unifi-os-server)
