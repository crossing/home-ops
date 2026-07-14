# Remove Stale MongoDB Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the unused insecure Nix MongoDB package and legacy nixpkgs input while preserving the UniFi OS container deployment on `gk`.

**Architecture:** UniFi remains an OCI container loaded from the existing Ubiquiti image derivation. The obsolete host-side MongoDB override, insecure-package exception, and old channel input are deleted together, then the lock graph and `gk` system are evaluated as one coherent change.

**Tech Stack:** Nix flakes, Snowfall Lib, NixOS, Git

## Global Constraints

- Do not modify the UniFi container definition, official image package, firewall rules, or `/var/lib/unifi` data volume.
- The insecure MongoDB package must no longer be permitted or exposed by the repository.
- The `gk` NixOS configuration must evaluate successfully.

---

### Task 1: Remove the obsolete MongoDB dependency path

**Files:**
- Modify: `flake.nix`
- Modify: `flake.lock`
- Delete: `overlays/mongodb/default.nix`

**Interfaces:**
- Consumes: Snowfall's automatic overlay discovery and the root flake input graph.
- Produces: A root flake with no `nixpkgs-old`, MongoDB overlay, or insecure MongoDB exception; the existing `nixosConfigurations.gk` output remains available.

- [ ] **Step 1: Run the pre-change regression checks**

Run:

```bash
rg -n 'nixpkgs-old|mongodb-7_0|mongodb-7\.0\.25|permittedInsecurePackages' flake.nix flake.lock overlays
```

Expected: matches in `flake.nix`, `flake.lock`, and `overlays/mongodb/default.nix`, proving the obsolete dependency path exists.

- [ ] **Step 2: Remove the obsolete configuration**

Delete `nixpkgs-old.url = "nixpkgs/nixos-25.05";` from `flake.nix`, remove the complete `permittedInsecurePackages` attribute, and delete `overlays/mongodb/default.nix`.

- [ ] **Step 3: Regenerate only the root lock graph affected by the deleted input**

Run:

```bash
XDG_CACHE_HOME=/tmp/home-ops-remove-mongodb-cache nix flake lock
```

Expected: exit 0; the root `nixpkgs-old` node and root reference disappear from `flake.lock` without changing unrelated locked revisions.

- [ ] **Step 4: Run focused static checks**

Run:

```bash
if rg -n 'nixpkgs-old|mongodb-7_0|mongodb-7\.0\.25|permittedInsecurePackages' flake.nix flake.lock overlays; then exit 1; fi
rg -n 'containers\.unifi|unifi-os-server|/var/lib/unifi:/unifi' systems/x86_64-linux/gk/configuration/unifi.nix packages/unifi-os-server/default.nix
git diff --check
```

Expected: no obsolete MongoDB matches; UniFi container, image, and persistent data mount matches remain; `git diff --check` exits 0.

- [ ] **Step 5: Evaluate and build the `gk` configuration**

Run the narrow evaluation first:

```bash
XDG_CACHE_HOME=/tmp/home-ops-remove-mongodb-cache nix eval --raw '.#nixosConfigurations.gk.config.system.build.toplevel.drvPath'
```

Expected: exit 0 and a `/nix/store/...-nixos-system-gk-....drv` path.

Then run the repository's target build:

```bash
XDG_CACHE_HOME=/tmp/home-ops-remove-mongodb-cache nix build '.#nixosConfigurations.gk.config.system.build.toplevel' -L
```

Expected: exit 0. If remote dependencies or local machine resources prevent the full build, preserve and report the first actionable error while retaining successful evaluation as the minimum evidence.

- [ ] **Step 6: Commit the implementation**

Run:

```bash
git add flake.nix flake.lock overlays/mongodb/default.nix
git commit -m "Remove stale insecure MongoDB package"
```

Expected: one implementation commit containing only the obsolete dependency removal and lockfile update.
