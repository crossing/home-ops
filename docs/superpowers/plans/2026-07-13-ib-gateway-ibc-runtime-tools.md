# IB Gateway IBC Autorestart Parser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore reliable scheduled IBC restarts by removing the failing external-command pipeline from IBC's autorestart parser, then resume the paused dual-live runtime proof.

**Architecture:** Keep the Gateway image, wrapper, generated systemd services, and secret flow unchanged. Test the real packaged `find_auto_restart` function under the observed restricted-command condition, patch IBC 3.24.1 to use Bash parameter expansion, rebuild all affected Nix outputs, and then repeat the sanitized service lifecycle and pension-login checks.

**Tech Stack:** Nix, Home Manager, Bash, Podman, Ubuntu 24.04, IBC 3.24.1, systemd user services, `safe-op`/1Password CLI.

## Global Constraints

- Work only in `/tmp/home-ops-ibkr-gateway` on `feature/ibkr-local-integration`.
- Never print credentials, OTPs, account identifiers, financial rows, generated IBC configuration, or scoped 1Password session values.
- Use `safe-op` as the boundary for every secret read; raw `op` is limited to session state and non-secret metadata.
- Preserve the constrained `ibkr-local` API surface; submit, cancel, and modify remain unavailable.
- Stage every new file before Nix evaluation because the flake reads the tracked Git tree.

---

### Task 1: Add an IBC autorestart parser regression test

**Files:**
- Create: `packages/ibgateway/test-ibc-autorestart.sh`

**Interfaces:**
- Consumes: a path to a packaged `scripts/ibcstart.sh`.
- Produces: exit 0 only when the real `find_auto_restart` function derives `-Drestart=session` while only `find` is available externally.

- [x] **Step 1: Write the failing test**

Create an executable test that extracts `find_auto_restart` from the supplied
IBC script, creates `Jts/session/autorestart`, provides `find` as a shell
function, sets `PATH` to an intentionally absent directory, invokes the
extracted function, and asserts:

The committed test extracts the function with `awk`, creates a temporary
`Jts/session/autorestart`, supplies `find` as a shell function, clears `PATH`,
and requires both of these assertions:

```bash
if [[ "$autorestart_option" != " -Drestart=session" ]]; then
  echo "unexpected autorestart option" >&2
  exit 1
fi
if [[ "$restart_needed" != yes ]]; then
  echo "restart was not marked as needed" >&2
  exit 1
fi
```

- [x] **Step 2: Verify RED against the unpatched package**

Run:

```bash
chmod +x packages/ibgateway/test-ibc-autorestart.sh
bash packages/ibgateway/test-ibc-autorestart.sh /nix/store/zyyb8zk8zwz2ijmwmhq29i2sl6kd4hz2-ibc-3.24.1/scripts/ibcstart.sh
```

Expected: nonzero with `xargs: command not found` and `cut: command not found`, matching the scheduled-restart journal.

- [x] **Step 3: Commit the verified failing test**

Run:

```bash
git add packages/ibgateway/test-ibc-autorestart.sh
git diff --cached --check
git commit -m "test(ibkr): cover IBC autorestart parsing"
```

Expected: one committed executable test and no production change.

---

### Task 2: Patch IBC autorestart parsing

**Files:**
- Create: `packages/ibgateway/ibc-autorestart-builtins.patch`
- Modify: `packages/ibgateway/default.nix`

**Interfaces:**
- Consumes: the fetched IBC 3.24.1 source tree.
- Produces: a patched IBC derivation whose one-level autorestart path parser uses only Bash parameter expansion after `find` returns a file.

- [x] **Step 1: Add the minimal source patch**

Replace the `xargs dirname`/`cut` parsing variables with:

```bash
local parent=${x%/*}
local relative_parent=${parent#/}
if [[ -n "$relative_parent" && "$relative_parent" != */* ]]; then
```

Use `relative_parent` as `autorestart_path`. Preserve the existing duplicate
file cleanup and restart-needed behavior.

Add the patch to the IBC derivation's `patches` and expose the derivation as
`passthru.ibc` on the final `ibgateway` package for direct regression testing.

- [x] **Step 2: Verify GREEN**

Run:

```bash
ibc_path=$(nix build --no-link --print-out-paths '.#packages.x86_64-linux.ibgateway.ibc')
bash packages/ibgateway/test-ibc-autorestart.sh "$ibc_path/scripts/ibcstart.sh"
```

Expected: exit 0 and `PASS: IBC autorestart parser uses Bash path handling`.

- [x] **Step 3: Run focused static checks and commit**

Run:

```bash
bash -n packages/ibgateway/test-ibc-autorestart.sh packages/ibgateway/wrapper.sh
git diff --check
git add packages/ibgateway/default.nix packages/ibgateway/ibc-autorestart-builtins.patch
git commit -m "fix(ibkr): harden IBC autorestart parsing"
```

Expected: syntax and whitespace checks pass; only the IBC packaging change is committed.

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

Record the failure cause, parser fix, build evidence, lifecycle result, live profile state, and exact next step without secrets or financial data. Then run:

```bash
git diff --check
git add HANDOFF-ibkr-gateway-runtime.md
git commit -m "docs(ibkr): record IBC restart regression test"
```

Expected: the handoff is the only file in the final documentation commit and `git status --short` is empty.
