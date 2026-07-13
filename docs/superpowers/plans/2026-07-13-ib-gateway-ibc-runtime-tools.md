# IB Gateway IBC Runtime Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore reliable scheduled IBC restarts by ensuring the Gateway container contains every shell command used by IBC, then resume the paused dual-live runtime proof.

**Architecture:** Keep the Gateway wrapper, generated systemd services, and secret flow unchanged. Add an image-level smoke test for IBC's required commands, minimally extend the Ubuntu image dependencies, rebuild all affected Nix outputs, and then repeat the sanitized service lifecycle and pension-login checks.

**Tech Stack:** Nix, Home Manager, Bash, Podman, Ubuntu 24.04, IBC 3.24.1, systemd user services, `safe-op`/1Password CLI.

## Global Constraints

- Work only in `/tmp/home-ops-ibkr-gateway` on `feature/ibkr-local-integration`.
- Never print credentials, OTPs, account identifiers, financial rows, generated IBC configuration, or scoped 1Password session values.
- Use `safe-op` as the boundary for every secret read; raw `op` is limited to session state and non-secret metadata.
- Preserve the constrained `ibkr-local` API surface; submit, cancel, and modify remain unavailable.
- Stage every new file before Nix evaluation because the flake reads the tracked Git tree.

---

### Task 1: Add an image-level runtime-tool regression test

**Files:**
- Create: `packages/ibgateway/test-runtime-tools.sh`

**Interfaces:**
- Consumes: `PODMAN` as an optional absolute Podman executable and `packages/ibgateway/Dockerfile`.
- Produces: exit 0 only when a freshly built test image resolves both `xargs` and `cut`; no container data or secrets are emitted.

- [ ] **Step 1: Write the failing test**

Create this executable test:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
podman=${PODMAN:-podman}
image=localhost/ibgateway-runtime-tools-test:local

cleanup() {
  "$podman" image rm --force "$image" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"$podman" build --quiet --tag "$image" --file "$script_dir/Dockerfile" "$script_dir" >/dev/null
"$podman" run --rm "$image" bash -euc '
  failed=0
  for tool in xargs cut; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf "missing runtime tool: %s\\n" "$tool" >&2
      failed=1
    fi
  done
  exit "$failed"
'
printf 'IB Gateway runtime tools available: xargs cut\n'
```

- [ ] **Step 2: Verify RED against the current image**

Run:

```bash
chmod +x packages/ibgateway/test-runtime-tools.sh
nix shell nixpkgs#podman -c bash packages/ibgateway/test-runtime-tools.sh
```

Expected: nonzero with `missing runtime tool: xargs` and `missing runtime tool: cut`. If the local image cache differs, require at least one missing-tool failure and correlate it with the journal evidence before proceeding.

- [ ] **Step 3: Commit the verified failing test**

Run:

```bash
git add packages/ibgateway/test-runtime-tools.sh
git diff --cached --check
git commit -m "test(ibkr): cover IBC container runtime tools"
```

Expected: one committed executable test and no production change.

---

### Task 2: Install the missing IBC runtime commands

**Files:**
- Modify: `packages/ibgateway/Dockerfile`

**Interfaces:**
- Consumes: Ubuntu package repositories used by the existing image build.
- Produces: `xargs` from `findutils` and `cut` from `coreutils` inside every newly hashed Gateway image.

- [ ] **Step 1: Add the minimal image dependencies**

Add these entries to the existing `apt-get install` list immediately after `ca-certificates`:

```dockerfile
    coreutils \
    findutils \
```

- [ ] **Step 2: Verify GREEN**

Run:

```bash
nix shell nixpkgs#podman -c bash packages/ibgateway/test-runtime-tools.sh
```

Expected: exit 0 and `IB Gateway runtime tools available: xargs cut`.

- [ ] **Step 3: Run focused static checks and commit**

Run:

```bash
bash -n packages/ibgateway/test-runtime-tools.sh packages/ibgateway/wrapper.sh
git diff --check
git add packages/ibgateway/Dockerfile
git commit -m "fix(ibkr): install IBC runtime tools"
```

Expected: syntax and whitespace checks pass; only the Dockerfile dependency change is committed.

---

### Task 3: Rebuild and repeat the sanitized runtime proof

**Files:**
- Modify: `HANDOFF-ibkr-gateway-runtime.md`

**Interfaces:**
- Consumes: rebuilt `ibgateway`, `ibkr-local`, and Home Manager generation plus the existing generated reauthentication/coordinator commands.
- Produces: evidence that scheduled-restart dependencies exist, cleanup succeeds, `main-live` and `pension-live` reach their strongest safely verifiable state, and the handoff matches the final runtime state.

- [ ] **Step 1: Build every affected output**

Run sequentially:

```bash
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibgateway -L
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibkr-local -L
nix build --no-link --print-out-paths '.#homeConfigurations."xing@desktop".activationPackage' -L
bash modules/home/ibkr-local/test-ibkr-gateway-ensure.sh
git diff --check
```

Expected: all builds and the four-case coordinator test exit 0.

- [ ] **Step 2: Install only verified generation state**

Record the previous IBKR unit targets and Home Manager generation path. Attempt normal activation. If the pre-existing Home Manager link conflict recurs, leave unrelated paths untouched and link/reload only the IBKR units from the newly built generation using the rollback pattern already documented in `HANDOFF-ibkr-gateway-runtime.md`.

- [ ] **Step 3: Reauthenticate from one persistent local shell**

Run `op signin --account my.1password.com`, verify only that `op whoami` succeeds, and invoke `ibkr-gateway-ensure-live`. Do not inspect or print any secret-bearing field. Complete each broker-offered IB Key challenge manually when it arrives.

- [ ] **Step 4: Verify lifecycle and idempotence**

Require:

```text
main-live service active; port 4001 listening
pension-live service active; port 4003 listening
one deterministic container per active profile
runtime credential files mode 0600
no OP_SESSION_* or OP_ACCOUNT variable present in either service environment
second coordinator invocation reports both profiles already active
service invocation IDs unchanged across the second invocation
```

If pension 2FA remains unavailable, stop and clean only `pension-live`, preserve a healthy `main-live`, and record the external device boundary.

- [ ] **Step 5: Run sanitized API checks**

Use the rebuilt `ibkr-local` to run `connect`, `positions`, `balances`, and `executions` for each authenticated profile. Report only connection status and row counts. Run the existing `order-preview ... --submit` rejection check and require nonzero exit without submitting an order.

- [ ] **Step 6: Update and commit the handoff**

Record the failure cause, image fix, build evidence, lifecycle result, live profile state, and exact next step without secrets or financial data. Then run:

```bash
git diff --check
git add HANDOFF-ibkr-gateway-runtime.md
git commit -m "docs(ibkr): record IBC restart regression test"
```

Expected: the handoff is the only file in the final documentation commit and `git status --short` is empty.
