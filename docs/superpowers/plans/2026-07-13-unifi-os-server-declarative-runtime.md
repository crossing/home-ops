# Declarative UniFi OS Server Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the pinned official UniFi OS Server 5.1.21 image on `gk` as a fully declarative rootless Podman service, prove persistence and cold-boot recovery in a disposable VM, and cut over from the legacy controller with a reversible data migration.

**Architecture:** Nix extracts the embedded OCI archive from Ubiquiti's untouched, hash-pinned installer. A disabled-by-default NixOS module owns the `uosserver` account, rootless Podman preparation, seven named volumes, stable per-install UUID, port map, and systemd lifecycle; the vendor updater and installer-generated host files are not used. The old `/var/lib/unifi`, its final `.unf`, and the prior NixOS generation remain intact for rollback.

**Tech Stack:** NixOS 26.05, Snowfall, rootless Podman, `pasta`, systemd, NixOS VM tests, Ubiquiti UniFi OS Server 5.1.21.

## Global Constraints

- Use only the official 5.1.21 installer pinned by its existing Ubiquiti URL and SHA-256.
- Preserve the verified pre-AVX bundled-MongoDB result; an AVX requirement is a hard stop.
- Keep the seven vendor persistence boundaries as named Podman volumes.
- Do not run the vendor updater service or allow an in-application upgrade to replace declarative state.
- Do not mount, modify, or delete legacy `/var/lib/unifi` during preparation or initial cutover.
- Do not enable remote cloud management, factory-reset devices, forget devices, or manually re-adopt them.
- Do not mutate live `gk` until the package test, VM lifecycle test, runbook review, and full `gk` build all pass.
- Preserve the previous NixOS generation and two verified backup copies until at least seven stable days have elapsed.

---

## File Structure

- Modify `packages/unifi-os-server/default.nix`: install the untouched vendor executable and extract its embedded OCI archive into the Nix store.
- Modify `packages/unifi-os-server/source.json`: pin the loaded image reference and immutable image ID found during release inspection.
- Modify `packages/unifi-os-server/update.sh`: verify and write the image reference and image ID with the installer pin.
- Create `modules/nixos/unifi-os-server/default.nix`: define the disabled-by-default declarative rootless service.
- Modify `systems/x86_64-linux/gk/configuration/unifi.nix`: enable the shared module with the pinned package and approved firewall policy.
- Replace `tests/unifi-os-server-vm.nix`: verify first boot, health, seven-volume persistence, container recreation, shutdown, and cold boot.
- Create `docs/runbooks/unifi-os-server-cutover.md`: provide exact backup, deploy, restore, acceptance, and rollback gates.

### Task 1: Package the Embedded OCI Archive

**Files:**
- Modify: `packages/unifi-os-server/default.nix`
- Modify: `packages/unifi-os-server/source.json`
- Modify: `packages/unifi-os-server/update.sh`
- Test: `tests/unifi-os-server-package.sh`

**Interfaces:**
- Consumes: the exact installer URL/hash in `source.json`.
- Produces: `$out/share/unifi-os-server/image.tar`, `passthru.image`, and the untouched `$out/bin/unifi-os-server-installer`.

- [ ] **Step 1: Write the failing package contract test**

Create `tests/unifi-os-server-package.sh` to build `.#unifi-os-server`, assert the OCI archive exists, load it into an isolated Podman store, and assert that `source.json`'s image reference resolves to its pinned image ID.

- [ ] **Step 2: Run the contract test and verify RED**

Run: `bash tests/unifi-os-server-package.sh`

Expected: failure because `share/unifi-os-server/image.tar` and image metadata do not exist.

- [ ] **Step 3: Extract the image reproducibly**

In `default.nix`, locate the appended ZIP by scanning EOCD records exactly as `update.sh` does, extract only `image.tar`, and install it read-only. Add `source.imageReference` and `source.imageId` as package passthru values.

- [ ] **Step 4: Extend release inspection metadata**

After extracting the OCI layout, make `update.sh` read the archive's `io.containerd.image.name` annotation and manifest digest, validate both, and write `imageReference` and `imageId` to `source.json` alongside the existing pin.

- [ ] **Step 5: Run the contract test and verify GREEN**

Run: `bash tests/unifi-os-server-package.sh`

Expected: the official archive loads and the pinned image ID/reference match.

- [ ] **Step 6: Commit the package contract**

Run: `git add packages/unifi-os-server tests/unifi-os-server-package.sh && git diff --cached --check && git commit -m "Expose pinned UniFi OS Server image"`

### Task 2: Declare the Rootless Runtime

**Files:**
- Create: `modules/nixos/unifi-os-server/default.nix`
- Modify: `systems/x86_64-linux/gk/configuration/unifi.nix`
- Test: `tests/unifi-os-server-vm.nix`

**Interfaces:**
- Consumes: `package`, `package.passthru.image`, `imageReference`, and `imageId` from Task 1.
- Produces: `services.unifi-os-server.enable`, `package`, `webPort`, and `openFirewall`; systemd units `unifi-os-server-prepare.service` and `unifi-os-server.service`.

- [ ] **Step 1: Replace the installer test with a failing declarative lifecycle test**

Import the module into a 4096 MiB/20 GiB NixOS test VM, enable it, and assert the named units and seven volume names exist. Test HTTPS health, write a marker into `uosserver_persistent`, remove/recreate only the container, verify the marker, shut down/start the VM, and verify health plus the marker again.

- [ ] **Step 2: Run the VM test and verify RED**

Run:

```bash
nix build --impure --expr '
  let flake = builtins.getFlake (toString ./.); pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  in import ./tests/unifi-os-server-vm.nix { inherit pkgs flake; }
' -L
```

Expected: evaluation failure because `modules/nixos/unifi-os-server/default.nix` does not exist.

- [ ] **Step 3: Implement preparation without secrets in logs**

Define the system account and sub-ID ranges, Podman/pasta dependencies, tmpfiles, and a oneshot preparation unit. The unit must generate `/var/lib/uosserver/uuid` once with mode `0600`, load the image only when its pinned ID is absent, verify the loaded ID, and idempotently create exactly these volumes: `uosserver_persistent`, `uosserver_var_log`, `uosserver_data`, `uosserver_srv`, `uosserver_etc_rabbitmq_ssl`, `uosserver_var_lib_mongodb`, and `uosserver_var_lib_unifi`.

- [ ] **Step 4: Implement the systemd-owned container**

Run rootless Podman as `uosserver` with `pasta`, the inventoried health command, capabilities, seven mounts, and exact vendor port mappings. Read the UUID inside the wrapper without printing it. Omit `--detach` so systemd tracks the foreground container; stop it with a 120-second timeout and restart on failure. Container recreation must remove only the named container, never volumes.

- [ ] **Step 5: Enable the module on `gk`**

Replace the prerequisite-only host configuration with `services.unifi-os-server.enable = true`, the flake package, web port `11443`, and the existing LAN firewall list. Retain the IPv6 assertion and 2 GiB swap.

- [ ] **Step 6: Run the lifecycle test and verify GREEN**

Run the Step 2 build. Expected: first health, marker persistence after forced recreation, and health/marker persistence after cold boot all pass.

- [ ] **Step 7: Commit the declarative runtime**

Run: `git add modules/nixos/unifi-os-server systems/x86_64-linux/gk/configuration/unifi.nix tests/unifi-os-server-vm.nix && git diff --cached --check && git commit -m "Run UniFi OS Server declaratively"`

### Task 3: Prove the Cutover and Rollback Path

**Files:**
- Create: `docs/runbooks/unifi-os-server-cutover.md`

**Interfaces:**
- Consumes: the tested service and the live legacy controller.
- Produces: a bounded migration procedure with explicit acceptance and rollback commands.

- [ ] **Step 1: Write the runbook**

Document preflight resource checks, two copies plus hashes of the final `.unf`, a cold archive of `/var/lib/unifi`, deployment of the prepared NixOS generation, restore through the local UniFi OS UI, and checks for service health, device inventory, adoption state, traffic, and reboot recovery. Rollback must stop the new unit, boot/switch the prior generation, restore the cold archive only if legacy data changed, and verify the legacy UI/devices.

- [ ] **Step 2: Verify repository and host builds**

Run: `git diff --check`, the package test, the VM lifecycle test, and `nix build '.#nixosConfigurations.gk.config.system.build.toplevel' -L`.

Expected: all commands exit 0. Do not deploy on any failure.

- [ ] **Step 3: Commit the runbook**

Run: `git add docs/runbooks/unifi-os-server-cutover.md && git diff --cached --check && git commit -m "Document reversible UniFi OS cutover"`

### Task 4: Merge and Perform the Reversible Migration

**Files:**
- No source changes expected.

**Interfaces:**
- Consumes: the passing branch and runbook.
- Produces: merged `master`, a deployed healthy UniFi OS Server, or a verified legacy rollback.

- [ ] **Step 1: Review and merge directly**

Inspect the complete branch diff, rerun verification, merge `feat/unifi-os-server-migration` into the original worktree without rewriting unrelated user changes, and rebuild the merged `gk` target.

- [ ] **Step 2: Capture final live backups before downtime**

Via `ssh deploy@gk`, record the current generation/service state, create the final `.unf`, hash two verified copies, stop legacy UniFi, and create/hash a cold archive of `/var/lib/unifi`. Stop if either backup cannot be read back.

- [ ] **Step 3: Deploy and restore**

Deploy the already-built generation, wait for the declarative container to become healthy, then restore the final `.unf` through the local UI. Do not enable cloud management or alter device adoption manually.

- [ ] **Step 4: Accept or roll back**

Accept only if the UI, expected sites/devices, adoption state, client traffic, persistence, and a controlled reboot all pass. Otherwise execute the runbook rollback immediately and verify the legacy controller is healthy.

---

## Self-Review

- Spec coverage: OCI provenance, non-AVX gate, rootless lifecycle, seven persistence boundaries, cold boot, backups, data restore, acceptance, and rollback each have an explicit task.
- Placeholder scan: no deferred implementation placeholders remain.
- Interface consistency: package metadata feeds the module; the module feeds the VM test and `gk`; the passing generation feeds the runbook and live cutover.
