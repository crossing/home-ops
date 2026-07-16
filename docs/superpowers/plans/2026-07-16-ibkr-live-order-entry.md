# Guarded IBKR Live Order Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `ibkr` the guarded local CLI and allow explicit, preview-ticketed, at-most-once live limit-order submission and cancellation while preserving `ibkr-local` compatibility.

**Architecture:** The Home Manager module writes a fail-closed per-profile order-entry policy. The wrapper prepares canonical short-lived tickets from upstream what-if responses, atomically consumes them before submission, and writes durable audit records; the unrestricted upstream CLI is called only by absolute Nix store path. `ibkr-local` is a compatibility symlink to the same guarded `ibkr` wrapper.

**Tech Stack:** Bash 5, jq, GNU coreutils, Nix/Home Manager, Snowfall, pinned `ibkr-cli` 0.7.1, shell regression tests.

## Global Constraints

- Keep `packages/ibkr-local` as the user-facing package.
- Install guarded `bin/ibkr`; retain `bin/ibkr-local` as an output-compatible symlink.
- Do not expose `${ibkr-cli}/bin/ibkr` through the package output or wrapper runtime `PATH`.
- Default every profile's order-entry policy to disabled.
- Require explicit profile and account for every prepare, submit, and cancel operation.
- Initial live scope is stock `LMT`, `DAY`, regular-hours buy/sell plus explicit cancellation.
- Keep market, stop, trailing, bracket, outside-hours, non-`DAY`, and modification operations blocked.
- Use 120-second tickets, atomic single-use submission, and no automatic retry or offsetting order.
- Never include credentials, 1Password state, environment dumps, or Gateway configuration in audit records.
- Do not touch authenticated Gateway services during automated verification.
- Stage new files before Nix evaluation because the flake reads the tracked tree.

---

## File structure

- Modify `packages/ibkr-local/default.nix`: package the guarded `ibkr` command, inject the absolute upstream path, source the focused order-entry library, and add the compatibility symlink.
- Modify `packages/ibkr-local/ibkr-local.sh`: use the injected upstream path, rename help/error output, and dispatch order commands.
- Create `packages/ibkr-local/order-entry.sh`: own policy validation, ticket creation, atomic submission, cancellation, and audit state.
- Create `packages/ibkr-local/test-cli-boundary.sh`: prove command naming, compatibility, and hidden upstream behavior.
- Create `packages/ibkr-local/test-order-entry.sh`: exercise the order state machine against a fake upstream CLI.
- Modify `modules/home/ibkr-local/default.nix`: define and serialize per-profile order-entry policy.
- Create `modules/home/ibkr-local/test-order-entry-policy.sh`: evaluate fail-closed defaults and generated JSON.
- Modify `homes/x86_64-linux/xing@desktop/ibkr.nix`: enable the validated policy for paper, then both live profiles after the paper proof.

### Task 1: Guarded CLI name and upstream boundary

**Files:**
- Modify: `packages/ibkr-local/default.nix`
- Modify: `packages/ibkr-local/ibkr-local.sh:4-39,163-198`
- Create: `packages/ibkr-local/test-cli-boundary.sh`

**Interfaces:**
- Consumes: pinned package `pkgs.${namespace}."ibkr-cli"` with `${ibkrCli}/bin/ibkr`.
- Produces: package binaries `bin/ibkr` and `bin/ibkr-local`; environment variable `IBKR_UPSTREAM` fixed to the absolute upstream executable.

- [ ] **Step 1: Write the failing CLI-boundary test**

Create a shell test that builds the package passed as `$1` and asserts:

```bash
#!/usr/bin/env bash
set -euo pipefail

package=${1:?usage: test-cli-boundary.sh PACKAGE_PATH}
primary="$package/bin/ibkr"
compat="$package/bin/ibkr-local"

[[ -x "$primary" ]]
[[ -x "$compat" ]]
[[ "$(readlink -f "$compat")" == "$(readlink -f "$primary")" ]]
"$primary" --help | grep -q '^Usage: ibkr '
cmp <("$primary" --help) <("$compat" --help)
if find "$package/bin" -maxdepth 1 -type l -lname '*ibkr-cli*' | grep -q .; then
  echo 'FAIL: unrestricted upstream ibkr is exposed' >&2
  exit 1
fi
printf 'PASS: guarded ibkr is primary and ibkr-local is compatible\n'
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
result=$(nix build '.#packages.x86_64-linux.ibkr-local' --no-link --print-out-paths)
bash packages/ibkr-local/test-cli-boundary.sh "$result"
```

Expected: FAIL because `$result/bin/ibkr` does not exist and `ibkr-local` is not a symlink to it.

- [ ] **Step 3: Package the primary wrapper and compatibility symlink**

Change the package expression to this shape:

```nix
let
  localPackages = pkgs.${namespace};
  ibkrCli = localPackages."ibkr-cli";
  ibgatewayPackage = localPackages.ibgateway;

  ibkr = pkgs.writeShellApplication {
    name = "ibkr";
    runtimeInputs = [
      ibgatewayPackage
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
    ];
    text = ''
      export IBKR_UPSTREAM=${lib.escapeShellArg "${ibkrCli}/bin/ibkr"}
      source ${./order-entry.sh}
      ${builtins.readFile ./ibkr-local.sh}
    '';
  };

  compatibility = pkgs.runCommand "ibkr-local-compat" { } ''
    mkdir -p "$out/bin"
    ln -s ${ibkr}/bin/ibkr "$out/bin/ibkr-local"
  '';
in
pkgs.symlinkJoin {
  name = "ibkr-local";
  paths = [ ibkr compatibility ibgatewayPackage ];
  meta = {
    description = "Guarded local Interactive Brokers CLI and Gateway runtime";
    platforms = lib.platforms.linux;
  };
}
```

Create an initially empty `packages/ibkr-local/order-entry.sh` containing only:

```bash
#!/usr/bin/env bash
```

In `ibkr-local.sh`, set `readonly APP_NAME="ibkr"`, replace usage examples with `ibkr`, and replace both upstream invocations with:

```bash
"${IBKR_UPSTREAM:?IBKR_UPSTREAM is required}"
```

- [ ] **Step 4: Run boundary and existing policy tests**

Run:

```bash
bash -n packages/ibkr-local/ibkr-local.sh packages/ibkr-local/order-entry.sh packages/ibkr-local/test-cli-boundary.sh
result=$(nix build '.#packages.x86_64-linux.ibkr-local' --no-link --print-out-paths)
bash packages/ibkr-local/test-cli-boundary.sh "$result"
bash packages/ibkr-local/test-ibc-config-policy.sh
```

Expected: all commands exit zero and the compatibility help output is byte-identical.

- [ ] **Step 5: Commit the CLI boundary**

```bash
git add packages/ibkr-local/default.nix packages/ibkr-local/ibkr-local.sh packages/ibkr-local/order-entry.sh packages/ibkr-local/test-cli-boundary.sh
git commit -m "refactor(ibkr): make guarded CLI primary"
```

### Task 2: Declarative fail-closed order policy

**Files:**
- Modify: `modules/home/ibkr-local/default.nix:10-65,145-161`
- Create: `modules/home/ibkr-local/test-order-entry-policy.sh`

**Interfaces:**
- Produces: `.profiles[PROFILE].orderEntry` JSON with `enable`, `ticketTtlSeconds`, `allowedOrderTypes`, and `allowOutsideRth`.
- Consumed by: `order_policy_json PROFILE` in Task 3.

- [ ] **Step 1: Write the failing module-policy test**

The test evaluates the desktop profile and asserts exact policy values:

```bash
#!/usr/bin/env bash
set -euo pipefail

flake=${1:-.}
json=$(nix eval --json "$flake#homeConfigurations.\"xing@desktop\".config.programs.ibkrLocal.profiles")

jq -e '."main-paper".orderEntry == {
  enable: false,
  ticketTtlSeconds: 120,
  allowedOrderTypes: ["LMT"],
  allowOutsideRth: false
}' <<<"$json" >/dev/null
jq -e '."main-live".orderEntry.enable == false' <<<"$json" >/dev/null
jq -e '."pension-live".orderEntry.enable == false' <<<"$json" >/dev/null
printf 'PASS: order-entry policy defaults fail closed\n'
```

- [ ] **Step 2: Run the test to verify it fails**

Run `bash modules/home/ibkr-local/test-order-entry-policy.sh`.

Expected: FAIL because `orderEntry` is not a profile option.

- [ ] **Step 3: Add the policy submodule and serialize it**

Inside `profileType`, add:

```nix
orderEntry = lib.mkOption {
  type = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "guarded order submission for this profile";
      ticketTtlSeconds = lib.mkOption {
        type = lib.types.ints.between 30 600;
        default = 120;
        description = "Lifetime of a prepared order ticket in seconds.";
      };
      allowedOrderTypes = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [ "LMT" ]);
        default = [ "LMT" ];
        description = "Order types accepted by guarded order entry.";
      };
      allowOutsideRth = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether guarded orders may execute outside regular trading hours.";
      };
    };
  };
  default = { };
  description = "Fail-closed guarded order-entry policy.";
};
```

Add `orderEntry` to the `inherit (profile)` list in `configJson`.

- [ ] **Step 4: Verify the option and generated policy**

Run:

```bash
git add modules/home/ibkr-local/default.nix modules/home/ibkr-local/test-order-entry-policy.sh
bash modules/home/ibkr-local/test-order-entry-policy.sh
nix eval --json '.#homeConfigurations."xing@desktop".config.programs.ibkrLocal.profiles.main-live.orderEntry'
```

Expected: the test passes and evaluation returns the exact disabled default policy.

- [ ] **Step 5: Commit the declarative policy**

```bash
git commit -m "feat(ibkr): add fail-closed order policy"
```

### Task 3: Prepare canonical preview tickets

**Files:**
- Modify: `packages/ibkr-local/order-entry.sh`
- Modify: `packages/ibkr-local/ibkr-local.sh:12-40,373-440`
- Create: `packages/ibkr-local/test-order-entry.sh`

**Interfaces:**
- Produces: `cmd_order_prepare "$@"`; ticket schema version `1` under `$XDG_RUNTIME_DIR/ibkr-local/order-tickets/prepared/TICKET.json`.
- Ticket fields: `schemaVersion`, `ticketId`, `createdAt`, `expiresAt`, `checksum`, `profile`, `ibkrProfile`, `mode`, `account`, `order`, `contract`, and `preview`.

- [ ] **Step 1: Write failing prepare tests with a fake upstream**

Create a fake `IBKR_UPSTREAM` that logs argv and returns this preview payload:

```json
{
  "profile":"main-live",
  "preview_only":true,
  "selected_account":"TEST123",
  "symbol":"AAPL",
  "local_symbol":"AAPL",
  "exchange":"SMART",
  "primary_exchange":"NASDAQ",
  "currency":"USD",
  "sec_type":"STK",
  "con_id":265598,
  "status":"PreSubmitted",
  "commission":1,
  "min_commission":1,
  "max_commission":1,
  "commission_currency":"USD",
  "init_margin_change":100,
  "maint_margin_change":100,
  "equity_with_loan_change":-100,
  "warning_text":null,
  "raw_error_codes":[]
}
```

The test must run these cases and assert the outcomes shown:

```bash
expect_fail order-prepare buy AAPL 1 --profile disabled-live --account TEST123 --type LMT --limit 100
expect_fail order-prepare buy AAPL 1 --account TEST123 --type LMT --limit 100
expect_fail order-prepare buy AAPL 1 --profile main-live --type LMT --limit 100
expect_fail order-prepare buy AAPL 1 --profile main-live --account TEST123 --type MKT
expect_fail order-prepare buy AAPL 1 --profile main-live --account TEST123 --type LMT --limit 100 --outside-rth

ticket_json=$(run_cli order-prepare buy AAPL 1 --profile main-live --account TEST123 --type LMT --limit 100)
ticket_id=$(jq -er '.ticketId' <<<"$ticket_json")
ticket="$XDG_RUNTIME_DIR/ibkr-local/order-tickets/prepared/$ticket_id.json"
[[ -f "$ticket" ]]
[[ "$(stat -c %a "$ticket")" == 600 ]]
jq -e '.schemaVersion == 1 and .account == "TEST123" and .order.orderType == "LMT" and .order.limitPrice == 100' "$ticket" >/dev/null
```

- [ ] **Step 2: Run the prepare tests to verify they fail**

Run `bash packages/ibkr-local/test-order-entry.sh prepare`.

Expected: FAIL because `order-prepare` is unknown.

- [ ] **Step 3: Implement policy parsing and ticket creation**

Add these library entry points:

```bash
order_policy_json() {
  local profile=$1
  jq -cer --arg profile "$profile" '
    .profiles[$profile] as $p
    | if $p == null then error("unknown profile") else $p end
    | {
        ibkrProfile: (.ibkrProfile // $profile),
        mode: (.mode // "paper"),
        orderEntry: ((.orderEntry // {}) + {
          enable: (.orderEntry.enable // false),
          ticketTtlSeconds: (.orderEntry.ticketTtlSeconds // 120),
          allowedOrderTypes: (.orderEntry.allowedOrderTypes // ["LMT"]),
          allowOutsideRth: (.orderEntry.allowOutsideRth // false)
        })
      }
  ' "$profiles_json"
}

order_checksum() {
  jq -cS 'del(.checksum)' "$1" | sha256sum | cut -d' ' -f1
}

order_ticket_id() {
  od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
}
```

Implement `cmd_order_prepare` so it parses only the documented options,
requires explicit profile/account, validates positive quantity and limit price,
requires `LMT`, `DAY`, and regular hours, calls:

```bash
XDG_CONFIG_HOME="$ibkr_xdg_home" "$IBKR_UPSTREAM" \
  "$side" "$symbol" "$quantity" \
  --profile "$ibkr_profile" --account "$account" \
  --type LMT --limit "$limit_price" --tif DAY --preview --json
```

Require `.preview_only == true` and `.selected_account == $account`. Build the
schema above with `jq -n`, write it through a same-directory temporary file
under `umask 077`, calculate and insert `checksum`, atomically `mv` it to
`$ticket_id.json`, and print the final ticket JSON.

Dispatch `order-prepare)` to `cmd_order_prepare "$@"` and add it to help.

- [ ] **Step 4: Run prepare and regression tests**

```bash
bash packages/ibkr-local/test-order-entry.sh prepare
bash packages/ibkr-local/test-ibc-config-policy.sh
bash -n packages/ibkr-local/ibkr-local.sh packages/ibkr-local/order-entry.sh
```

Expected: all tests pass; the fake log contains `--preview` and never `--submit`.

- [ ] **Step 5: Commit ticket preparation**

```bash
git add packages/ibkr-local/order-entry.sh packages/ibkr-local/ibkr-local.sh packages/ibkr-local/test-order-entry.sh
git commit -m "feat(ibkr): prepare guarded order tickets"
```

### Task 4: At-most-once submission, audit, and cancellation

**Files:**
- Modify: `packages/ibkr-local/order-entry.sh`
- Modify: `packages/ibkr-local/ibkr-local.sh:22-40,373-440`
- Modify: `packages/ibkr-local/test-order-entry.sh`

**Interfaces:**
- Produces: `cmd_order_submit TICKET --confirm TICKET`; `cmd_order_cancel ORDER --profile PROFILE --account ACCOUNT --confirm ORDER`.
- Audit path: `$XDG_STATE_HOME/ibkr-local/orders/TICKET.json` with state `submitting`, `submitted`, `attempted-unknown`, or `rejected`.

- [ ] **Step 1: Add failing submit/cancel state-machine tests**

Extend the fake upstream with modes `success`, `reject`, `timeout`, and
`malformed`. Assert:

```bash
expect_fail order-submit "$ticket_id" --confirm wrong
expect_fail order-submit expired-ticket --confirm expired-ticket

run_cli order-submit "$ticket_id" --confirm "$ticket_id"
[[ "$(grep -c -- '--submit' "$fake_log")" == 1 ]]
expect_fail order-submit "$ticket_id" --confirm "$ticket_id"
[[ "$(grep -c -- '--submit' "$fake_log")" == 1 ]]
jq -e '.state == "submitted"' "$XDG_STATE_HOME/ibkr-local/orders/$ticket_id.json" >/dev/null

timeout_ticket=$(prepare_ticket)
FAKE_MODE=timeout expect_fail order-submit "$timeout_ticket" --confirm "$timeout_ticket"
jq -e '.state == "attempted-unknown"' "$XDG_STATE_HOME/ibkr-local/orders/$timeout_ticket.json" >/dev/null
FAKE_MODE=success expect_fail order-submit "$timeout_ticket" --confirm "$timeout_ticket"

expect_fail order-cancel 42 --profile main-live --account TEST123 --confirm 41
run_cli order-cancel 42 --profile main-live --account TEST123 --confirm 42
grep -q 'orders cancel 42.*--account TEST123' "$fake_log"
```

Start two background submit processes for one prepared ticket, wait for both,
and assert the fake log contains exactly one new `--submit` invocation.

- [ ] **Step 2: Run state-machine tests to verify they fail**

Run `bash packages/ibkr-local/test-order-entry.sh lifecycle`.

Expected: FAIL because submit and cancel commands are unknown.

- [ ] **Step 3: Implement atomic submission and durable state**

`cmd_order_submit` must:

1. Parse exactly `TICKET_ID --confirm TICKET_ID`.
2. Locate the prepared ticket and verify schema, checksum, expiry, confirmation,
   current enabled policy, explicit account, `LMT`, `DAY`, and regular hours.
3. Atomically `mv` the prepared ticket to the sibling runtime `claimed`
   directory. A failed same-filesystem rename means another process consumed it.
4. Create the `0700` audit directory, copy the claimed ticket into it, and write
   state `submitting` before invoking upstream. Do not contact the broker if the
   durable audit record cannot be created.
5. Reconstruct every order flag from the ticket and append `--submit --json`.
6. On parsed success, write `submitted`; on a parsed broker rejection, write
   `rejected`; on all other failures write `attempted-unknown`.
7. Never restore the prepared ticket and never retry.

Use one audit updater so every state preserves the original ticket:

```bash
order_write_audit() {
  local path=$1 state=$2 response=${3:-null}
  local tmp="$path.tmp.$$"
  jq --arg state "$state" --argjson response "$response" \
    '. + {state: $state, updatedAt: (now | floor), brokerResponse: $response}' \
    "$path" >"$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$path"
}
```

`cmd_order_cancel` must validate explicit arguments and current policy, create a
random audit ID prefixed `cancel-`, write `submitting`, call:

```bash
XDG_CONFIG_HOME="$ibkr_xdg_home" "$IBKR_UPSTREAM" orders cancel "$order_id" \
  --profile "$ibkr_profile" --account "$account" --json
```

and use the same terminal-state classification without retries.

- [ ] **Step 4: Run lifecycle and all focused tests**

```bash
bash packages/ibkr-local/test-order-entry.sh lifecycle
bash packages/ibkr-local/test-order-entry.sh all
bash packages/ibkr-local/test-cli-boundary.sh "$(nix build '.#packages.x86_64-linux.ibkr-local' --no-link --print-out-paths)"
bash packages/ibkr-local/test-ibc-config-policy.sh
```

Expected: all pass; concurrent submission produces one upstream call; timeout
records `attempted-unknown`; no audit file contains strings matching
`password|usernameRef|passwordRef|op://`.

- [ ] **Step 5: Commit the order lifecycle**

```bash
git add packages/ibkr-local/order-entry.sh packages/ibkr-local/ibkr-local.sh packages/ibkr-local/test-order-entry.sh
git commit -m "feat(ibkr): submit and cancel guarded orders"
```

### Task 5: Profile rollout, builds, and runtime acceptance gates

**Files:**
- Modify: `homes/x86_64-linux/xing@desktop/ibkr.nix`
- Test: all focused IBKR shell tests and Nix targets.

**Interfaces:**
- Consumes: completed guarded CLI and order policy.
- Produces: enabled order-entry policy for `main-paper`, `main-live`, and `pension-live` after staged acceptance.

- [ ] **Step 1: Enable paper policy and verify the full static surface**

Add to `main-paper` only:

```nix
orderEntry.enable = true;
```

Update `test-order-entry-policy.sh` for this rollout phase so it requires
`main-paper.orderEntry.enable == true` and both live profiles to remain false.

Stage the configuration, then run:

```bash
git add homes/x86_64-linux/xing@desktop/ibkr.nix
bash packages/ibkr-local/test-order-entry.sh all
bash packages/ibkr-local/test-ibc-config-policy.sh
bash packages/ibkr-local/test-cli-boundary.sh "$(nix build '.#packages.x86_64-linux.ibkr-local' --no-link --print-out-paths)"
bash modules/home/ibkr-local/test-order-entry-policy.sh
bash modules/home/ibkr-local/test-api-trust-policy.sh
bash modules/home/ibkr-local/test-ibkr-gateway-ensure.sh
bash -n packages/ibkr-local/*.sh modules/home/ibkr-local/*.sh
nixpkgs-fmt --check packages/ibkr-local/default.nix modules/home/ibkr-local/default.nix homes/x86_64-linux/xing@desktop/ibkr.nix
nix build '.#packages.x86_64-linux.ibkr-local' -L
nix build '.#homeConfigurations."xing@desktop".activationPackage' -L
git diff --check
```

Expected: every focused test and both Nix builds pass without touching live
Gateway services.

- [ ] **Step 2: Record rollback state and perform paper lifecycle**

Record `home-manager generations` before activation. Activate only the verified
generation. Prepare a deliberately non-marketable `DAY` limit order against the
paper profile and explicit paper account, submit its ticket once, confirm it is
open, then cancel it once. If any result is ambiguous, stop and inspect broker
orders; do not retry.

Expected: one paper order is accepted and then cancelled, with matching local
audit records and no duplicate order.

- [ ] **Step 3: Enable both live profiles after paper acceptance**

Add this exact setting to `main-live` and `pension-live`:

```nix
orderEntry.enable = true;
```

Update `test-order-entry-policy.sh` to require `enable == true` for paper and
both live profiles. Re-run every static check and both Nix builds from Step 1.

- [ ] **Step 4: Activate guarded live capability without submitting an order**

Activate the second verified generation. Confirm:

```bash
command -v ibkr
command -v ibkr-local
ibkr --help
cmp <(ibkr --help) <(ibkr-local --help)
```

Prepare a user-chosen live limit-order ticket and inspect its account, contract,
price, expiry, preview warnings, margin change, and commission. Stop before
`order-submit`. Live submission requires a separate explicit instruction from
the user.

- [ ] **Step 5: Final verification and commit**

```bash
git add homes/x86_64-linux/xing@desktop/ibkr.nix modules/home/ibkr-local/test-order-entry-policy.sh
git diff --cached --check
git status --short
git commit -m "feat(ibkr): enable guarded live order entry"
```

Expected: the worktree is clean, the live profiles expose only the guarded
ticket workflow, and no live order has been submitted by automated acceptance.
