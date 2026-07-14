# Reversible `gk` UniFi OS Server Cutover

This runbook migrates the legacy UniFi Network Server on `gk` to the declarative rootless UniFi OS Server service. It preserves `/var/lib/unifi`, the pre-cutover NixOS generation, and verified backup copies so a failed migration can return to the exact legacy application/database pair.

Ubiquiti's current guidance requires the old Network Server to be closed before UniFi OS Server starts. For Linux migration it supports an offline Network backup (`.unf`) and, when needed, Site Export/Import. See [Self-Hosting UniFi](https://help.ui.com/hc/en-us/articles/34210126298775-Self-Hosting-UniFi), [Backups and Migration](https://help.ui.com/hc/en-us/articles/360008976393-Backups-and-Migration-in-UniFi), and the [Required Ports Reference](https://help.ui.com/hc/en-us/articles/218506997-Required-Ports-Reference).

## Hard stop conditions

Stop before deployment if any of these are false:

- `tests/unifi-os-server-package.sh` passes.
- `tests/unifi-os-server-vm.nix` passes shutdown hardening, initial health, container replacement, persistence, and cold boot.
- The complete `gk` system build passes.
- The final `.unf` opens as a non-empty file and has two matching hashes: the downloaded off-host copy and the preserved source copy.
- The stopped legacy data has a readable cold archive with matching on-host and off-host hashes.
- `/nix/var/nix/profiles/system-15-link/bin/switch-to-configuration` still exists.

Do not enable remote management, factory-reset devices, forget devices, or manually re-adopt them during this cutover.

## Workstation SSH setup

The current workstation has a working 1Password agent socket but its default OpenSSH configuration is not usable. Run this procedure in Bash and explicitly select the agent without changing or exposing any key:

```bash
SSH_GK=(
  ssh
  -F /dev/null
  -o IdentityAgent="$HOME/.1password/agent.sock"
  -o BatchMode=yes
  deploy@gk
)
```

Approve the local 1Password SSH request when prompted. Never copy a private key to `gk` or pass one on the command line.

## 1. Verify the built migration generation

From the repository root:

```bash
XDG_CACHE_HOME=/tmp/home-ops-unifi-nix-cache \
  bash tests/unifi-os-server-package.sh

XDG_CACHE_HOME=/tmp/home-ops-unifi-nix-cache nix build --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  in import ./tests/unifi-os-server-vm.nix { inherit pkgs flake; }
' -L

XDG_CACHE_HOME=/tmp/home-ops-unifi-nix-cache \
  nix build '.#nixosConfigurations.gk.config.system.build.toplevel' -L
```

Do not continue on any non-zero exit.

## 2. Record the live baseline

```bash
backup_dir="$HOME/backups/gk-unifi-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$backup_dir"

"${SSH_GK[@]}" '
  set -eu
  hostname
  readlink -f /run/current-system
  systemctl is-active unifi.service
  sudo test -x /nix/var/nix/profiles/system-15-link/bin/switch-to-configuration
  if grep -qw avx /proc/cpuinfo; then exit 1; else echo avx-absent; fi
  free -h
  df -h / /var/lib/unifi
  sudo nix-env --list-generations -p /nix/var/nix/profiles/system | tail -10
' | tee "$backup_dir/host-baseline.txt"
```

In the legacy UI, record into `$backup_dir/operator-baseline.txt`:

- UniFi Network version.
- Site names and count.
- Device names, models, and count.
- Which devices are online before downtime.
- Whether any devices use Layer 3 adoption or a controller hostname rather than `192.168.1.3`.

## 3. Create and verify the final migration backup

In the legacy UI at `https://192.168.1.3:8443`, open **Settings > Control Plane > Backups**, create a Network-only offline backup, and download the resulting `.unf` to the new `$backup_dir`. If the deployment uses multiple sites, also export each site from **Settings > System > Site Management** before stopping the service.

Verify the downloaded backup and preserve a second copy on `gk`:

```bash
unf=$(find "$backup_dir" -maxdepth 1 -type f -name '*.unf' -print -quit)
test -n "$unf"
test -s "$unf"
sha256sum "$unf" | tee "$backup_dir/final-unf.sha256"

cat "$unf" | "${SSH_GK[@]}" '
  sudo install -d -m 0700 /var/backups/unifi-migration
  sudo tee /var/backups/unifi-migration/final-network.unf >/dev/null
  sudo chmod 0600 /var/backups/unifi-migration/final-network.unf
  sudo sha256sum /var/backups/unifi-migration/final-network.unf
' | tee "$backup_dir/final-unf.remote.sha256"

test "$(cut -d" " -f1 "$backup_dir/final-unf.sha256")" = \
  "$(cut -d" " -f1 "$backup_dir/final-unf.remote.sha256")"
```

Stop if the hashes differ.

## 4. Stop legacy UniFi and create the cold archive

This begins downtime.

```bash
"${SSH_GK[@]}" '
  set -eu
  sudo systemctl stop unifi.service
  test "$(systemctl is-active unifi.service || true)" = inactive
  if pgrep -a -u unifi "java|mongod"; then
    echo "legacy processes still running" >&2
    exit 1
  fi
  sudo install -d -m 0700 /var/backups/unifi-migration
  sudo tar --acls --xattrs --numeric-owner -C / \
    -czf /var/backups/unifi-migration/legacy-unifi-cold.tgz \
    var/lib/unifi
  sudo gzip -t /var/backups/unifi-migration/legacy-unifi-cold.tgz
  sudo sha256sum /var/backups/unifi-migration/legacy-unifi-cold.tgz
' | tee "$backup_dir/legacy-cold.remote.sha256"

"${SSH_GK[@]}" \
  'sudo cat /var/backups/unifi-migration/legacy-unifi-cold.tgz' \
  >"$backup_dir/legacy-unifi-cold.tgz"
gzip -t "$backup_dir/legacy-unifi-cold.tgz"
sha256sum "$backup_dir/legacy-unifi-cold.tgz" \
  | tee "$backup_dir/legacy-cold.local.sha256"

test "$(cut -d" " -f1 "$backup_dir/legacy-cold.remote.sha256")" = \
  "$(cut -d" " -f1 "$backup_dir/legacy-cold.local.sha256")"
```

Stop if the hashes differ or either archive fails `gzip -t`.

## 5. Install the already-tested generation for the next boot

Do not live-activate this generation. A live 25.11 to 26.05 switch on `gk`
timed out while reloading the system D-Bus service, and the cross-generation
rollback activation then entered a userspace loop. Install the new generation
as the boot default while the known-good legacy generation remains running:

```bash
XDG_CACHE_HOME=/tmp/home-ops-unifi-nix-cache \
  deploy \
    --boot \
    --skip-checks \
    --ssh-opts "-F /dev/null -o IdentityAgent=$HOME/.1password/agent.sock -o BatchMode=yes" \
    .#gk

"${SSH_GK[@]}" '
  set -eu
  echo "running=$(readlink -f /run/current-system)"
  echo "next_boot=$(readlink -f /nix/var/nix/profiles/system)"
  test "$(readlink -f /run/current-system)" != \
    "$(readlink -f /nix/var/nix/profiles/system)"
  sudo bootctl list --no-pager | sed -n "1,12p"
'
```

Confirm the new generation is marked as the boot default and generation 15 is
still listed. Then reboot once from the clean legacy generation:

```bash
"${SSH_GK[@]}" 'sudo systemctl reboot'
```

Wait for `gk` to answer ICMP before making one new authenticated SSH
connection. The first image import can use roughly 3.5 GiB RAM and take several
minutes. Wait for readiness without restarting it prematurely:

```bash
"${SSH_GK[@]}" '
  set -eu
  systemctl is-active unifi-os-server.service
  curl -kfsS https://127.0.0.1:11443/ >/dev/null
  swapon --show
  runuser -u uosserver -- env \
    HOME=/var/lib/uosserver XDG_RUNTIME_DIR=/run/uosserver \
    podman ps --filter name=uosserver --format "{{.Names}} {{.Status}}"
  ss -lntup | grep -E ":(5671|6789|8080|8444|8880|8881|8882|9543|11443|28082) "
  ss -lnup | grep -E ":(3478|5514|10003) "
' | tee "$backup_dir/new-runtime.txt"
```

Rollback immediately if the unit cannot reach active state within five minutes, enters a restart loop, exhausts swap, or the HTTPS endpoint never responds.

## 6. Restore Network data

Open `https://192.168.1.3:11443` locally. Keep remote management disabled during migration. Complete only the minimum local setup needed to reach **Settings > Control Plane > Backups**, upload the final `.unf`, and restore the Network application.

If the `.unf` is rejected or fails to reproduce all sites, stop. Use the already exported Site files only if the UI offers the documented Import Site flow and it does not require forgetting or resetting devices. Otherwise roll back; do not improvise device adoption during the outage.

## 7. Acceptance gate

All checks must pass before the migration is accepted:

- Local administrator login works at port 11443.
- Site names/count and device names/models match `operator-baseline.txt`.
- Every previously online device returns online without a reset, forget, or manual adoption.
- Inform traffic reaches TCP 8080 and STUN reaches UDP 3478.
- Any UXG traffic-flow integration works through TCP 5671.
- A harmless change can be provisioned to one selected device and then reverted.
- Topology, clients, events, and historical configuration are usable.
- A fresh backup can be created and downloaded from UniFi OS Server.
- `free -h`, `swapon --show`, and `journalctl -u unifi-os-server.service` show no OOM or restart loop.

Then perform one additional controlled reboot:

```bash
"${SSH_GK[@]}" 'sudo systemctl reboot'
```

After SSH returns:

```bash
"${SSH_GK[@]}" '
  set -eu
  systemctl is-active unifi-os-server.service
  curl -kfsS https://127.0.0.1:11443/ >/dev/null
  runuser -u uosserver -- env \
    HOME=/var/lib/uosserver XDG_RUNTIME_DIR=/run/uosserver \
    podman volume exists uosserver_persistent
  free -h
  swapon --show
  journalctl -u unifi-os-server.service -b --priority=warning --no-pager
'
```

Recheck the UI and device baseline after reboot. Begin the seven-day soak only after every check passes.

## Rollback

Rollback is preferred over factory reset, forgetting devices, or debugging
under prolonged outage. Do not use a live cross-generation switch. Select
generation 15 for the next boot, sync the filesystem, and reboot:

```bash
"${SSH_GK[@]}" '
  set -eu
  sudo systemctl stop unifi-os-server.service || true
  sudo /nix/var/nix/profiles/system-15-link/bin/switch-to-configuration boot
  sudo sync
  sudo systemctl reboot
'
```

If the normal reboot command cannot reach systemd, run `sudo sync` and then
`sudo systemctl reboot --force --force`. If SSH is unavailable, select
generation 15 from the local systemd-boot menu. After `gk` returns:

```bash
"${SSH_GK[@]}" '
  set -eu
  test "$(readlink -f /run/current-system)" = \
    "$(readlink -f /nix/var/nix/profiles/system-15-link)"
  systemctl is-active unifi.service
  curl -kfsS https://127.0.0.1:8443/ >/dev/null
'
```

Because the new runtime never mounts `/var/lib/unifi`, normally no data restore is required. If that directory was changed outside this runbook, keep `unifi.service` stopped and restore only from the verified archive:

```bash
"${SSH_GK[@]}" '
  set -eu
  sudo systemctl stop unifi.service
  sudo mv /var/lib/unifi /var/lib/unifi.failed-cutover
  sudo tar --acls --xattrs --numeric-owner -C / \
    -xzf /var/backups/unifi-migration/legacy-unifi-cold.tgz
  sudo systemctl start unifi.service
  systemctl is-active unifi.service
'
```

Verify legacy UI login, sites, devices, and provisioning. Preserve `/var/lib/uosserver` for diagnosis; do not purge its container volumes during rollback.

## Delayed cleanup

For at least seven stable days, retain:

- NixOS generation 15.
- `/var/lib/unifi` and both cold-archive copies.
- Both final `.unf` copies.
- `/var/lib/uosserver` and all seven volumes.

Only after a new-server backup and the full soak pass should legacy data, rollback generations, or obsolete closures be considered for removal.
