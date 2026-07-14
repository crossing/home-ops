# UniFi OS Server Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy UniFi Network 10.2.105 and MongoDB 7.0.25 service on `gk` with Ubiquiti's supported installer-managed UniFi OS Server while preserving a tested generation-and-data rollback.

**Architecture:** NixOS declaratively provides Podman, `pasta`, swap, service-account prerequisites, persistent directories, and a least-privilege firewall. Ubiquiti's pinned official Linux installer manages its rootless Podman container and volumes. A disposable NixOS VM proves installer compatibility and reboot behavior before the live controller is stopped; a final `.unf` backup and cold archive preserve rollback.

**Tech Stack:** NixOS 26.05 flake, Snowfall, Podman, `pasta`, systemd, Ubiquiti UniFi OS Server Linux x64 installer, QEMU/KVM, SSH, deploy-rs.

## Global Constraints

- Use an official stable UniFi OS Server Linux x64 release version 5.1.19 or newer; 5.1.19 fixes Security Advisory Bulletin 066.
- Pin the installer by exact Ubiquiti URL and SHA-256 in `packages/unifi-os-server/default.nix`.
- Repeat the bundled-MongoDB startup probe on `gk`; AVX absence is a hard gate.
- Do not deploy the repository's standalone Docker image extraction.
- Do not mount or modify legacy `/var/lib/unifi` as the new UniFi OS Server persistence root.
- Do not factory-reset, forget, or manually re-adopt devices during the initial migration.
- Do not enable remote cloud management without explicit user approval.
- Preserve NixOS generation 15 and two verified off-host backups until at least seven stable days have elapsed.
- Stop at every explicit `STOP` instruction and report the captured evidence before continuing.

---

## File Structure

- Modify `packages/unifi-os-server/default.nix`: package the pinned official installer as an executable, not an extracted container image.
- Create `packages/unifi-os-server/update.sh`: resolve and verify a selected official release, calculate its hash, extract the embedded OCI image, identify bundled MongoDB, and run the pre-AVX emulation probe.
- Create `packages/unifi-os-server/source.json`: machine-generated pin containing the exact official URL and SRI hash consumed by the Nix package.
- Modify `systems/x86_64-linux/gk/configuration/unifi.nix`: declare Podman/pasta prerequisites, swap, persistence directories, IPv6 assertion, and current UniFi OS Server firewall ports; remove Docker OCI-container configuration.
- Create `tests/unifi-os-server-vm.nix`: disposable NixOS VM test for installer health, port binding, idempotence, and reboot survival.
- Create `docs/runbooks/unifi-os-server-cutover.md`: exact live backup, cutover, acceptance, rollback, and delayed-cleanup procedure.

---

### Task 1: Pin and Validate the Official Release

**Files:**
- Create: `packages/unifi-os-server/update.sh`
- Create: `packages/unifi-os-server/source.json`
- Modify: `packages/unifi-os-server/default.nix`

**Interfaces:**
- Consumes: Official Ubiquiti releases page and Linux x64 installer URL.
- Produces: `packages.unifi-os-server`, an executable installer at `$out/bin/unifi-os-server-installer`, plus an update script that fails if the bundled MongoDB cannot run without AVX.

- [ ] **Step 1: Record the selected stable release**

Open the official release page and select UniFi OS Server 5.1.21 for Linux x64:

```bash
xdg-open https://www.ui.com/download/releases/unifi-os-server
```

Copy the exact `fw-download.ubnt.com/data/unifi-os-server/...-linux-x64-<version>-...-x64` URL. Confirm its release page is marked Official, not Release Candidate.

Expected: version `5.1.21`, release state Official, and an HTTPS URL under `fw-download.ubnt.com`. If 5.1.21 is no longer downloadable, stop and amend the specification with the replacement version before continuing.

- [ ] **Step 2: Write a release-inspection script**

Create `packages/unifi-os-server/update.sh` with this behavior:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 VERSION OFFICIAL_INSTALLER_URL" >&2
  exit 64
fi

version=$1
url=$2
case "$url" in
  https://fw-download.ubnt.com/data/unifi-os-server/*-linux-x64-"$version"-*-x64) ;;
  *) echo "unexpected Ubiquiti installer URL: $url" >&2; exit 65 ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
installer="$work/unifi-os-server-installer"
curl -fL --retry 3 -o "$installer" "$url"
chmod +x "$installer"

hash=$(nix hash file --type sha256 --sri "$installer")
echo "version=$version"
echo "url=$url"
echo "hash=$hash"

# The installer is an ELF executable with one or more appended ZIP archives.
# Locate the ZIP containing image.tar by testing each local-header offset.
mapfile -t offsets < <(LC_ALL=C grep -aob $'PK\003\004' "$installer" | cut -d: -f1)
payload=
for offset in "${offsets[@]}"; do
  candidate="$work/payload-$offset.zip"
  dd if="$installer" of="$candidate" bs=1M iflag=skip_bytes skip="$offset" status=none
  if unzip -t "$candidate" image.tar >/dev/null 2>&1; then
    payload=$candidate
    break
  fi
done
test -n "$payload"
unzip -q "$payload" image.tar -d "$work"
chmod u+r "$work/image.tar"
mkdir "$work/oci" "$work/rootfs"
tar -xf "$work/image.tar" -C "$work/oci"

manifest_digest=$(jq -r '.manifests[0].digest | sub("^sha256:"; "")' "$work/oci/index.json")
jq -r '.layers[].digest | sub("^sha256:"; "")' \
  "$work/oci/blobs/sha256/$manifest_digest" |
while read -r layer; do
  tar -xf "$work/oci/blobs/sha256/$layer" -C "$work/rootfs"
done

mongod="$work/rootfs/usr/bin/mongod"
loader="$work/rootfs/lib/x86_64-linux-gnu/ld-2.31.so"
libs="$work/rootfs/lib/x86_64-linux-gnu:$work/rootfs/usr/lib/x86_64-linux-gnu"
test -x "$mongod"
test -x "$loader"
qemu-x86_64 -cpu Westmere "$loader" --library-path "$libs" "$mongod" --version

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
jq -n --arg version "$version" --arg url "$url" --arg hash "$hash" \
  '{version: $version, url: $url, hash: $hash}' >"$script_dir/source.json"
```

Use packages `bash`, `curl`, `coreutils`, `gnugrep`, `unzip`, `jq`, `gnutar`, and `qemu` from a temporary `nix shell` when running it.

- [ ] **Step 3: Run the release probe**

```bash
read -r -p 'Paste the official 5.1.21 Linux x64 URL: ' URL
nix shell \
  nixpkgs#bash nixpkgs#curl nixpkgs#coreutils nixpkgs#gnugrep \
  nixpkgs#unzip nixpkgs#jq nixpkgs#gnutar nixpkgs#qemu \
  -c packages/unifi-os-server/update.sh '5.1.21' "$URL"
```

Expected: printed SRI hash and `mongod --version` exits 0 under the pre-AVX Westmere CPU. Save the command output in `/tmp/unifi-os-server-release-evidence.txt`.

STOP if the image has no `/usr/bin/mongod`, the loader changes unexpectedly, the emulated probe raises `SIGILL`, or the selected release is not Official.

- [ ] **Step 4: Replace the image package with the installer package**

Change `packages/unifi-os-server/default.nix` to read the generated pin:

```nix
{ lib, stdenvNoCC, fetchurl }:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
stdenvNoCC.mkDerivation {
  pname = "unifi-os-server-installer";
  inherit (source) version;

  src = fetchurl {
    inherit (source) url hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/unifi-os-server-installer"
    runHook postInstall
  '';

  meta = {
    description = "Official Ubiquiti UniFi OS Server Linux installer";
    homepage = "https://www.ui.com/download/releases/unifi-os-server";
    license = lib.licenses.unfree;
    mainProgram = "unifi-os-server-installer";
    platforms = [ "x86_64-linux" ];
  };
}
```

Do not use `autoPatchelfHook`: rewriting this self-extracting ELF may discard or invalidate its appended ZIP payload. `gk` will use Nix's FHS loader compatibility for the untouched vendor executable. Verify `source.json` contains version `5.1.21`, an official Ubiquiti URL, and an SRI SHA-256 value.

- [ ] **Step 5: Build and smoke-test the packaged installer**

```bash
jq -e '.version == "5.1.21" and (.url | startswith("https://fw-download.ubnt.com/data/unifi-os-server/")) and (.hash | startswith("sha256-"))' packages/unifi-os-server/source.json
nix build .#unifi-os-server -L
./result/bin/unifi-os-server-installer --help
```

Expected: build succeeds and help begins with `Install or update UniFi OS Server`.

- [ ] **Step 6: Commit the release package**

```bash
git add packages/unifi-os-server/default.nix packages/unifi-os-server/source.json packages/unifi-os-server/update.sh
git diff --cached --check
git commit -m "Package official UniFi OS Server installer"
```

---

### Task 2: Declare NixOS Host Prerequisites

**Files:**
- Modify: `systems/x86_64-linux/gk/configuration/unifi.nix`
- Modify: `systems/x86_64-linux/gk/hardware.nix`

**Interfaces:**
- Consumes: `$out/bin/unifi-os-server-installer` from Task 1.
- Produces: a `gk` generation that prepares—but does not automatically run—the vendor installer.

- [ ] **Step 1: Write a failing static regression check**

Run:

```bash
if rg -n 'virtualisation\.oci-containers|virtualisation\.docker|imageFile|containers\.unifi' \
  systems/x86_64-linux/gk/configuration/unifi.nix; then
  exit 1
fi
rg -n 'virtualisation\.podman\.enable = true|passt|unifi-os-server-installer' \
  systems/x86_64-linux/gk/configuration/unifi.nix
```

Expected: FAIL because the unsupported Docker definition still exists and Podman prerequisites do not.

- [ ] **Step 2: Replace the Docker container definition**

Make `systems/x86_64-linux/gk/configuration/unifi.nix` declare:

```nix
{ config, lib, pkgs, inputs, ... }:
let
  lanTcpPorts = [ 6789 8080 8444 8880 8881 8882 11443 28082 ];
  lanUdpPorts = [ 3478 5514 10003 ];
in
{
  assertions = [
    {
      assertion = !(builtins.elem "ipv6.disable=1" config.boot.kernelParams);
      message = "UniFi OS Server requires IPv6 kernel support";
    }
  ];

  virtualisation.podman.enable = true;
  programs.nix-ld.enable = true;

  environment.systemPackages = [
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.unifi-os-server
    pkgs.passt
    pkgs.podman
    pkgs.shadow
    pkgs.slirp4netns
  ];

  users.users.uosserver = {
    isSystemUser = true;
    group = "uosserver";
    home = "/home/uosserver";
    createHome = true;
  };
  users.groups.uosserver = { };

  systemd.tmpfiles.rules = [
    "d /var/lib/uosserver 0750 uosserver uosserver - -"
    "d /home/uosserver 0750 uosserver uosserver - -"
    "f /var/lib/systemd/linger/uosserver 0644 root root - -"
  ];

  networking.firewall.allowedTCPPorts = lanTcpPorts;
  networking.firewall.allowedUDPPorts = lanUdpPorts;
}
```

Do not create an activation script or oneshot service that invokes the installer. Running it remains an explicit cutover action.

- [ ] **Step 3: Add swap**

Replace `swapDevices = [ ];` in `systems/x86_64-linux/gk/hardware.nix` with:

```nix
swapDevices = [
  {
    device = "/var/lib/swapfile";
    size = 2048;
  }
];
```

- [ ] **Step 4: Run the static regression check**

```bash
if rg -n 'virtualisation\.oci-containers|virtualisation\.docker|imageFile|containers\.unifi' \
  systems/x86_64-linux/gk/configuration/unifi.nix; then
  exit 1
fi
rg -n 'virtualisation\.podman\.enable = true|programs\.nix-ld\.enable = true|pkgs\.passt|unifi-os-server' \
  systems/x86_64-linux/gk/configuration/unifi.nix
rg -n 'device = "/var/lib/swapfile"|size = 2048' systems/x86_64-linux/gk/hardware.nix
```

Expected: no Docker matches; Podman, `passt`, installer package, and 2 GiB swap all match.

- [ ] **Step 5: Evaluate and build `gk`**

```bash
git add packages/unifi-os-server systems/x86_64-linux/gk/configuration/unifi.nix \
  systems/x86_64-linux/gk/hardware.nix
nix eval --raw '.#nixosConfigurations.gk.config.system.build.toplevel.drvPath'
nix build '.#nixosConfigurations.gk.config.system.build.toplevel' -L
```

Expected: evaluation and full system build succeed.

- [ ] **Step 6: Commit the prerequisite configuration**

```bash
git add systems/x86_64-linux/gk/configuration/unifi.nix systems/x86_64-linux/gk/hardware.nix
git diff --cached --check
git commit -m "Prepare gk for official UniFi OS Server"
```

---

### Task 3: Prove the Official Installer in a Disposable NixOS VM

**Files:**
- Create: `tests/unifi-os-server-vm.nix`

**Interfaces:**
- Consumes: the packaged installer and prerequisite configuration from Tasks 1-2.
- Produces: automated evidence that the installer, container, ports, idempotence, and reboot work on NixOS.

- [ ] **Step 1: Create the VM test**

Create `tests/unifi-os-server-vm.nix` as a `pkgs.testers.runNixOSTest` test with one machine. Import the Podman, package, user, tmpfiles, and swap settings from Task 2; give the VM 4096 MiB RAM and 20 GiB disk. The Python test must:

```python
machine.start()
machine.wait_for_unit("multi-user.target")
machine.succeed("swapon --show --noheadings | grep /var/lib/swapfile")
machine.succeed("podman --version")
machine.succeed("pasta --version")
machine.succeed("unifi-os-server-installer --help | grep 'Install or update UniFi OS Server'")
machine.succeed(
    "unifi-os-server-installer --non-interactive --network-mode pasta --web-port 11443"
)
machine.wait_for_unit("uosserver.service", timeout=180)
machine.wait_until_succeeds("curl -kfsS https://127.0.0.1:11443/ >/dev/null", timeout=180)
machine.succeed("runuser -u uosserver -- podman ps --format '{{.Names}} {{.Status}}' | grep '^uosserver .*healthy'")
machine.succeed("ss -lntup | grep -E ':(8080|8444|11443) '")
machine.succeed(
    "unifi-os-server-installer --non-interactive --force-install --network-mode pasta --web-port 11443"
)
machine.reboot()
machine.wait_for_unit("uosserver.service", timeout=180)
machine.wait_until_succeeds("curl -kfsS https://127.0.0.1:11443/ >/dev/null", timeout=180)
```

The Nix test must copy installer-created paths and `systemctl cat uosserver` into the test log before reboot so the host-mutation inventory is reviewable.

- [ ] **Step 2: Run the VM test and diagnose the first failure**

```bash
nix build --impure --expr '
  let pkgs = import <nixpkgs> { system = "x86_64-linux"; };
  in import ./tests/unifi-os-server-vm.nix { inherit pkgs; flake = builtins.getFlake (toString ./.); }
' -L
```

Expected: the first run may fail on an installer assumption. Capture the first actionable error and the exact missing path or command; do not add unrelated compatibility workarounds.

- [ ] **Step 3: Make only evidence-driven NixOS compatibility changes**

For each failure, update the VM node configuration and `gk` configuration together. Allowed changes are declared packages, tmpfiles directories, user/group properties, systemd user-session settings, and narrowly scoped sysctls required by the installer. Do not replace the installer-managed Podman command or extract/run its image directly.

After each single change, rerun the command from Step 2.

STOP after three distinct compatibility failures and revisit the Debian 13 VM architecture with the user.

- [ ] **Step 4: Verify idempotence and reboot evidence**

Expected final test output includes:

```text
uosserver.service ... active (running)
uosserver ... healthy
```

and the HTTPS probe succeeds both before and after reboot. Confirm no test step mounts `/var/lib/unifi`.

- [ ] **Step 5: Commit the VM test and any compatibility changes**

```bash
git add tests/unifi-os-server-vm.nix systems/x86_64-linux/gk/configuration/unifi.nix
git diff --cached --check
git commit -m "Test official UniFi OS Server on NixOS"
```

---

### Task 4: Write and Dry-Run the Cutover Runbook

**Files:**
- Create: `docs/runbooks/unifi-os-server-cutover.md`

**Interfaces:**
- Consumes: verified installer and NixOS generation from Tasks 1-3.
- Produces: operator checklist with immutable artifact names and rollback commands.

- [ ] **Step 1: Document preflight and backup commands**

The runbook must define `stamp=$(date -u +%Y%m%dT%H%M%SZ)` and use `/var/backups/unifi-migration/$stamp`. Include commands to:

```bash
ssh deploy@gk 'systemctl is-active unifi.service; free -h; df -h / /var/lib/unifi'
ssh deploy@gk 'sudo nix-env --list-generations -p /nix/var/nix/profiles/system | tail -10'
ssh deploy@gk 'sudo sha256sum /var/lib/unifi/data/backup/autobackup/autobackup_10.2.105_20260701_0030_1782865800007.unf'
ssh deploy@gk 'sudo cat /var/lib/unifi/data/backup/autobackup/autobackup_10.2.105_20260701_0030_1782865800007.unf' >./autobackup_10.2.105_20260701_0030_1782865800007.unf
sha256sum ./autobackup_10.2.105_20260701_0030_1782865800007.unf
```

The UI step must generate and download a new Network-only `.unf` immediately before downtime. Record its SHA-256 locally and on the off-host copy.

- [ ] **Step 2: Document cold backup commands**

Include:

```bash
ssh deploy@gk 'sudo systemctl stop unifi.service'
ssh deploy@gk 'sudo systemctl is-active unifi.service || true; pgrep -a -u unifi "java|mongod" && exit 1 || true'
ssh deploy@gk 'sudo install -d -m 0700 /var/backups/unifi-migration'
ssh deploy@gk 'sudo tar --acls --xattrs --numeric-owner -C / -czf /var/backups/unifi-migration/legacy-unifi-cold.tgz var/lib/unifi'
ssh deploy@gk 'sudo sha256sum /var/backups/unifi-migration/legacy-unifi-cold.tgz'
ssh deploy@gk 'sudo cat /var/backups/unifi-migration/legacy-unifi-cold.tgz' >./legacy-unifi-cold.tgz
sha256sum legacy-unifi-cold.tgz
```

The two checksums must match before continuing.

- [ ] **Step 3: Document exact rollback commands**

Include commands to stop `uosserver`, stop the rootless container, select generation 15, restore the archive only if `/var/lib/unifi` changed, and start legacy UniFi:

```bash
ssh deploy@gk 'sudo systemctl stop uosserver.service || true; sudo -u uosserver podman stop uosserver || true'
ssh deploy@gk 'sudo /nix/var/nix/profiles/system-15-link/bin/switch-to-configuration switch'
ssh deploy@gk 'sudo systemctl start unifi.service; systemctl is-active unifi.service'
ssh deploy@gk 'ss -lntup | grep -E ":(8080|8443) "'
```

Restoration must rename the failed tree rather than delete it:

```bash
sudo mv /var/lib/unifi /var/lib/unifi.failed-$stamp
sudo tar --acls --xattrs --numeric-owner -C / -xzf /var/backups/unifi-migration/legacy-unifi-cold.tgz
```

- [ ] **Step 4: Document acceptance and soak checks**

Include explicit checkboxes for site count, device count, previously-online devices, login/ownership, inform, STUN, one reversible test-device provisioning change, backup creation, reboot, service/container health, resource use, and seven daily checks.

- [ ] **Step 5: Dry-run every read-only command**

Run only inventory/status commands against `gk`. For mutation commands, verify syntax locally with `shellcheck` and mark them `NOT EXECUTED` in the runbook evidence section.

- [ ] **Step 6: Commit the runbook**

```bash
git add docs/runbooks/unifi-os-server-cutover.md
git diff --cached --check
git commit -m "Add UniFi OS Server cutover runbook"
```

---

### Task 5: Revalidate the Exact Release on `gk`

**Files:**
- No repository changes expected.

**Interfaces:**
- Consumes: exact pinned installer and extracted MongoDB from Task 1.
- Produces: real-CPU compatibility evidence for the final selected release.

- [ ] **Step 1: Confirm AVX remains absent**

```bash
ssh deploy@gk 'if grep -qw avx /proc/cpuinfo; then echo avx-present; else echo avx-absent; fi'
```

Expected: `avx-absent`.

- [ ] **Step 2: Copy only the selected release's MongoDB probe bundle**

Build a temporary archive containing `/usr/bin/mongod`, `/lib/x86_64-linux-gnu`, and `/usr/lib/x86_64-linux-gnu` from the selected image, copy it to `/tmp` on `gk`, and extract it under `/tmp/unifi-mongod-<version>-test`.

- [ ] **Step 3: Run the full startup probe**

Run the exact selected binary for eight seconds with:

```bash
testdir=/tmp/unifi-mongod-5.1.21-test
loader="$testdir/lib/x86_64-linux-gnu/ld-2.31.so"
libs="$testdir/lib/x86_64-linux-gnu:$testdir/usr/lib/x86_64-linux-gnu"
timeout --signal=TERM 8 "$loader" --library-path "$libs" "$testdir/usr/bin/mongod" \
  --dbpath "$testdir/db" --port 27119 --bind_ip 127.0.0.1 --nounixsocket \
  --logpath "$testdir/mongod-test.log"
```

Expected: log contains `waiting for connections on port 27119`, then clean shutdown code 0 after SIGTERM; `timeout` itself returns 124. No `Illegal instruction` or `SIGILL` appears.

STOP and retain the legacy controller if this probe fails.

- [ ] **Step 4: Remove temporary probe files**

Delete only `/tmp/unifi-mongod-5.1.21-test*` locally and on `gk`. Verify those paths no longer exist.

---

### Task 6: Stage the Prepared Closure Without Activation

**Files:**
- No additional repository changes expected.

**Interfaces:**
- Consumes: built `gk` system closure from Task 2.
- Produces: the complete prepared system closure on `gk` while the legacy controller remains active.

- [ ] **Step 1: Build and copy the closure**

```bash
nix build '.#nixosConfigurations.gk.config.system.build.toplevel' -L
nix copy --to ssh-ng://deploy@gk ./result
```

- [ ] **Step 2: Confirm rollback generation before activation**

```bash
ssh deploy@gk 'readlink -f /run/current-system; test -x /nix/var/nix/profiles/system-15-link/bin/switch-to-configuration'
```

Expected: generation 15 link exists and is executable.

- [ ] **Step 3: Verify staging did not alter the running system**

```bash
ssh deploy@gk 'systemctl is-active unifi.service; readlink -f /run/current-system; pgrep -a -u unifi "java|mongod"'
```

Expected: legacy service remains active, current system path is unchanged, and both Java and MongoDB are running.

STOP if copying the closure changed any live service.

---

### Task 7: Cold Backup, Activate, Install, and Migrate

**Files:**
- Update: `docs/runbooks/unifi-os-server-cutover.md` evidence section only.

**Interfaces:**
- Consumes: fresh `.unf`, verified cold archive, staged host closure, and pinned installer.
- Produces: migrated UniFi OS Server or a completed rollback.

- [ ] **Step 1: Execute the runbook preflight and backups**

Follow Task 4's commands exactly while the legacy controller is still active. Record timestamps, SHA-256 values, generation path, baseline site/device counts, and backup destinations.

STOP unless both the fresh `.unf` and cold archive exist off-host with matching checksums.

- [ ] **Step 2: Activate the prerequisite generation**

Use deploy-rs for the `gk` node only after the cold archive is verified:

```bash
nix run github:serokell/deploy-rs -- .#gk
```

The installer is not executed in this step. The legacy service is already cleanly stopped for the cold archive.

- [ ] **Step 3: Verify prerequisites**

```bash
ssh deploy@gk 'swapon --show; podman --version; pasta --version; id uosserver; test -d /var/lib/uosserver; test -d /home/uosserver; systemctl is-active unifi.service || true'
```

Expected: 2 GiB swap, Podman/pasta versions, `uosserver` identity/directories, and legacy service inactive.

STOP and roll back generation 15 if any prerequisite is missing.

- [ ] **Step 4: Run the official installer**

```bash
ssh -t deploy@gk 'sudo unifi-os-server-installer --network-mode pasta --web-port 11443'
```

Allow automatic Linux migration only if the installer explicitly identifies the legacy Network Server and previews the migration. Otherwise complete setup without adopting devices and restore the fresh `.unf` through Control Plane > Backups.

- [ ] **Step 5: Verify service and container health**

```bash
ssh deploy@gk 'systemctl status uosserver.service --no-pager; sudo -u uosserver podman ps --format "{{.Names}}|{{.Status}}"; ss -lntup | grep -E ":(3478|8080|8444|11443|28082) "'
```

Expected: service active, `uosserver` container healthy, and expected ports bound.

- [ ] **Step 6: Complete supported data migration**

Use this order:

1. Accept verified automatic migration if it succeeded.
2. Otherwise upload the fresh Network-only `.unf` in Control Plane > Backups.
3. If backup ownership prevents restore, stop and use Site Export/Import; do not create a parallel unmanaged deployment.

STOP and roll back if the new owner cannot restore the backup, sites are missing, or migration requests device resets.

- [ ] **Step 7: Run immediate acceptance checks**

Verify every item in the runbook: login, owner, sites, devices, inform, STUN, UI views, backup creation, resources, and logs. Make and revert one harmless configuration change on one preselected device.

- [ ] **Step 8: Reboot and verify again**

```bash
ssh deploy@gk 'sudo systemctl reboot'
```

Wait for SSH, then rerun service, container, port, UI, and device-online checks.

STOP and execute rollback immediately if service health, UI, or device connectivity does not recover.

- [ ] **Step 9: Commit cutover evidence**

Record no credentials, device secrets, private backup contents, or tokens. Commit only timestamps, versions, hashes, counts, health results, and rollback status:

```bash
git add docs/runbooks/unifi-os-server-cutover.md
git diff --cached --check
git commit -m "Record UniFi OS Server cutover evidence"
```

---

### Task 8: Soak and Delayed Cleanup

**Files:**
- Modify: `docs/runbooks/unifi-os-server-cutover.md`

**Interfaces:**
- Consumes: successful cutover and seven daily observations.
- Produces: accepted migration with intentional legacy-retention decision.

- [ ] **Step 1: Run daily checks for seven days**

Record:

```bash
ssh deploy@gk 'systemctl is-active uosserver.service; sudo -u uosserver podman ps --format "{{.Status}}"; free -h; swapon --show; df -h / /var/lib/uosserver; journalctl -u uosserver.service --since=-24h --priority=warning --no-pager'
```

Also verify devices online and that an automatic or manual backup can be downloaded.

- [ ] **Step 2: Obtain explicit cleanup approval**

Present seven-day evidence and ask whether generation 15, the cold archive, and old `/var/lib/unifi` may be retired. Do not infer approval from elapsed time.

- [ ] **Step 3: Remove legacy artifacts only after approval**

Keep at least one encrypted off-host `.unf` and cold archive according to the user's backup policy. Remove obsolete local legacy data and old generation only after checking the approved paths and current service health.

- [ ] **Step 4: Final verification**

```bash
nix build '.#nixosConfigurations.gk.config.system.build.toplevel' -L
ssh deploy@gk 'systemctl is-active uosserver.service; sudo -u uosserver podman ps --format "{{.Names}}|{{.Status}}"; swapon --show'
git status --short
```

Expected: build succeeds, service/container are healthy, swap is active, and Git working tree is clean.

- [ ] **Step 5: Commit final runbook state**

```bash
git add docs/runbooks/unifi-os-server-cutover.md
git diff --cached --check
git commit -m "Complete UniFi OS Server migration runbook"
```
