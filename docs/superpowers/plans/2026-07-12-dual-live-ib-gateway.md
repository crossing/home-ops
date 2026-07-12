# Dual Live IB Gateway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the pension live Gateway and provide an idempotent command that ensures both configured live Gateway services are active without restarting healthy sessions.

**Architecture:** Keep the existing generated per-profile services and reauthentication helpers as the only owners of credentials and Gateway lifecycle. Add a small shell coordinator whose behavior is independently testable, then have the Home Manager module generate `ibkr-gateway-ensure-live` from an explicit profile list.

**Tech Stack:** Nix/Home Manager, Bash, systemd user services, 1Password CLI metadata discovery, `safe-op` credential reads inside existing helpers.

## Global Constraints

- Work only in `/tmp/home-ops-ibkr-gateway` on `feature/ibkr-local-integration`.
- Preserve the active `main-live` service; do not activate Home Manager or run live reauthentication until static and build checks pass.
- Never print or inspect passwords, session tokens, generated IBC configuration, or secret-bearing environment values.
- Keep live mutation blocked; API write access exists only for what-if previews.
- Stage new files before Nix evaluation because the flake reads the tracked tree.

---

### Task 1: Test and implement the idempotent coordinator

**Files:**
- Create: `modules/home/ibkr-local/ibkr-gateway-ensure.sh`
- Create: `modules/home/ibkr-local/test-ibkr-gateway-ensure.sh`

**Interfaces:**
- Consumes: profile names as positional arguments; `systemctl` and `ibkr-gateway-reauth-PROFILE` from `PATH`.
- Produces: exit 0 only when every `ibkr-gateway-PROFILE.service` is active after the pass; credential-free per-profile status on stderr.

- [ ] **Step 1: Write the failing shell test**

Create a temporary `PATH` containing a stateful fake `systemctl` and fake `ibkr-gateway-reauth-main-live` / `ibkr-gateway-reauth-pension-live` commands. Run four isolated cases against the not-yet-created coordinator:

```bash
run_case both_active main-live=active pension-live=active
assert_helpers ""
assert_exit 0

run_case pension_missing main-live=active pension-live=inactive
assert_helpers "pension-live"
assert_exit 0

run_case both_missing main-live=inactive pension-live=inactive
assert_helpers $'main-live\npension-live'
assert_exit 0

run_case main_fails main-live=inactive pension-live=inactive main-live=fail
assert_helpers $'main-live\npension-live'
assert_service pension-live active
assert_exit 1
```

The fake reauthentication helper changes only its matching service state to `active` unless that profile is marked `fail`. Assertions must also prove that no helper was called for a service initially marked active.

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
bash modules/home/ibkr-local/test-ibkr-gateway-ensure.sh
```

Expected: nonzero with the coordinator file reported missing. The failure must be caused by the absent feature, not malformed test setup.

- [ ] **Step 3: Implement the minimal coordinator**

Create `ibkr-gateway-ensure.sh` with `set -uo pipefail`. Require at least one profile. For every profile:

```bash
service="ibkr-gateway-$profile.service"
helper="ibkr-gateway-reauth-$profile"
if systemctl --user -q is-active "$service"; then
  printf '%s: already active\n' "$profile" >&2
  continue
fi
if ! command -v "$helper" >/dev/null 2>&1; then
  printf '%s: missing reauthentication helper\n' "$profile" >&2
  failed=1
  continue
fi
if ! "$helper"; then
  printf '%s: reauthentication failed\n' "$profile" >&2
  failed=1
fi
if systemctl --user -q is-active "$service"; then
  printf '%s: active\n' "$profile" >&2
else
  printf '%s: inactive after start attempt\n' "$profile" >&2
  failed=1
fi
```

Reject empty or option-like profile names before constructing command names. Continue across failures and exit with the accumulated result.

- [ ] **Step 4: Run the focused test and syntax checks**

Run:

```bash
bash modules/home/ibkr-local/test-ibkr-gateway-ensure.sh
bash -n modules/home/ibkr-local/ibkr-gateway-ensure.sh modules/home/ibkr-local/test-ibkr-gateway-ensure.sh
```

Expected: all four cases pass and both scripts parse successfully.

- [ ] **Step 5: Review and commit the coordinator slice**

Run `git diff --check`, review only the two new scripts, then:

```bash
git add modules/home/ibkr-local/ibkr-gateway-ensure.sh modules/home/ibkr-local/test-ibkr-gateway-ensure.sh
git commit -m "feat(ibkr): add idempotent gateway coordinator"
```

---

### Task 2: Generate the aggregate command and enable pension-live

**Files:**
- Modify: `modules/home/ibkr-local/default.nix`
- Modify: `homes/x86_64-linux/xing@desktop/ibkr.nix`

**Interfaces:**
- Consumes: `programs.ibkrLocal.gateway.ensureProfiles`, whose entries must identify enabled Gateway profiles.
- Produces: `ibkr-gateway-ensure-live` in `home.packages`, generated with the configured profile order `main-live`, then `pension-live`.

- [ ] **Step 1: Add failing Nix evaluation checks**

Before module edits, run these and preserve their expected missing-option/missing-package failures:

```bash
nix eval --json '.#homeConfigurations."xing@desktop".config.programs.ibkrLocal.gateway.ensureProfiles'
nix eval --raw '.#homeConfigurations."xing@desktop".config.systemd.user.services.ibkr-gateway-pension-live.Service.Restart'
```

Expected: `ensureProfiles` is absent and the pension service lookup fails before implementation.

- [ ] **Step 2: Discover the pension Login item without revealing secrets**

Use raw `op` only for metadata. Authorize once if needed, enumerate Login item IDs, and select the unique item whose non-concealed username field equals `crossing2pension`. Emit only the item ID, vault ID, title, and matching username label; never output the password field or full item JSON.

Construct stable references in this form without reading either secret:

```text
op://VAULT_ID/ITEM_ID/username
op://VAULT_ID/ITEM_ID/password
```

If zero or multiple items match, stop and resolve the ambiguity rather than guessing.

- [ ] **Step 3: Add the module option and generated package**

In `gateway`, add:

```nix
ensureProfiles = lib.mkOption {
  type = lib.types.listOf lib.types.str;
  default = [ ];
  description = "Ordered Gateway profiles managed by ibkr-gateway-ensure-live.";
};
```

Assert every entry exists in `enabledExistingGatewayProfiles`. When the list is nonempty, generate the command beside `gatewayReauthScripts`:

```nix
gatewayEnsureScript = lib.optional (cfg.gateway.ensureProfiles != [ ]) (
  pkgs.writeShellScriptBin "ibkr-gateway-ensure-live" ''
    exec ${pkgs.bash}/bin/bash ${./ibkr-gateway-ensure.sh} \
      ${lib.escapeShellArgs cfg.gateway.ensureProfiles}
  ''
);
```

Include `gatewayEnsureScript` in `home.packages` beside the per-profile reauthentication helpers.

- [ ] **Step 4: Enable and configure pension-live**

In `ibkr.nix`, set:

```nix
gateway.ensureProfiles = [ "main-live" "pension-live" ];
```

Add `gateway.profiles.pension-live` with the discovered stable username/password references and the same runtime policy as `main-live`: `displayMode = "xvfb"`, `readOnlyApi = false`, `readOnlyLogin = false`, and `secondFactorDevice = "IB Key"`. Preserve the existing port 4003 and client ID 22 in `profiles.pension-live`.

- [ ] **Step 5: Stage and verify GREEN evaluations**

Stage the modified/new files, then run:

```bash
git add modules/home/ibkr-local homes/x86_64-linux/xing@desktop/ibkr.nix
nix eval --json '.#homeConfigurations."xing@desktop".config.programs.ibkrLocal.gateway.ensureProfiles'
nix eval --raw '.#homeConfigurations."xing@desktop".config.systemd.user.services.ibkr-gateway-main-live.Service.Restart'
nix eval --raw '.#homeConfigurations."xing@desktop".config.systemd.user.services.ibkr-gateway-pension-live.Service.Restart'
```

Expected: the list is `["main-live","pension-live"]`; both restart policies are `no`.

- [ ] **Step 6: Verify generated aggregate behavior without live mutation**

Build the activation package, locate `ibkr-gateway-ensure-live` in its generated home path, and run it only against a fake `PATH`/fake systemctl test environment. Do not invoke it against the live user manager in this step. Confirm the packaged command passes the same active/skip and inactive/start cases as Task 1.

- [ ] **Step 7: Run broad static and build verification**

Run sequentially:

```bash
bash modules/home/ibkr-local/test-ibkr-gateway-ensure.sh
bash -n modules/home/ibkr-local/ibkr-gateway-ensure.sh packages/ibgateway/wrapper.sh packages/ibkr-local/ibkr-local.sh
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibgateway -L
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibkr-local -L
nix build --no-link --print-out-paths '.#homeConfigurations."xing@desktop".activationPackage' -L
git diff --check
```

Re-run the built `ibkr-local order-preview ... --submit` rejection check and require a nonzero exit with the existing fail-closed message.

- [ ] **Step 8: Review and commit the configuration slice**

Inspect `git diff --cached` for credential values or unrelated changes. Stable `op://` references may be committed; secret values may not. Commit:

```bash
git commit -m "feat(ibkr): enable dual live gateways"
```

---

### Task 3: Controlled runtime proof and handoff update

**Files:**
- Modify: `HANDOFF-ibkr-gateway-runtime.md`

**Interfaces:**
- Consumes: the newly built Home Manager generation and `ibkr-gateway-ensure-live`.
- Produces: two active named Gateway services without restarting an already-active `main-live`, plus a durable verification record.

- [ ] **Step 1: Capture rollback state and activate safely**

Record the current Home Manager generation path, current `main-live` active state, and current named container count without printing service environments or credential files. Attempt normal Home Manager activation only after the full build passes. If the known unrelated skill-link conflict recurs, leave that path untouched and link/reload only the freshly built IBKR units and commands as documented in the existing handoff.

- [ ] **Step 2: Prove idempotent live orchestration**

From the user's 1Password-authorized terminal, run `ibkr-gateway-ensure-live`. Confirm its output reports `main-live` already active and invokes reauthentication only for `pension-live`. Complete the pension account's manual IB Key challenge when offered.

Run the command a second time. Confirm both profiles report already active, neither reauthentication helper runs, and the original main service invocation ID/start timestamp is unchanged.

- [ ] **Step 3: Verify sanitized runtime state**

Confirm both services are active, exactly one deterministic container exists per profile, ports 4001 and 4003 listen, and each runtime `ibc.ini` has mode 0600. Verify no `OP_SESSION_*` or `OP_ACCOUNT` value entered either service environment without printing the environment itself.

Run `ibkr-local connect --profile pension-live` and sanitized row-count checks for positions/balances/executions. Do not print account identifiers or financial rows. Confirm `order-preview --submit` remains blocked.

- [ ] **Step 4: Update handoff and commit**

Update `HANDOFF-ibkr-gateway-runtime.md` with the dual-instance proof, exact aggregate command, idempotency result, profile ports, and any remaining manual second-factor boundary. Run `git diff --check`, stage the handoff, and commit:

```bash
git commit -m "docs(ibkr): record dual gateway verification"
```
