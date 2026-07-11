# IBKR Gateway Runtime Handoff

Date: 2026-07-09
Branch: `feature/ibkr-local-integration`
Current HEAD: `e49f477 Harden IB Gateway reauth flow`

This is the short resume note for the IB Gateway runtime test. The longer historical handover is `IBKR_LOCAL_HANDOVER.md`.

## Current State

- Before this handoff file was added, the worktree was clean on `feature/ibkr-local-integration`.
- `ibkr-gateway-main-live.service` is inactive.
- `op whoami --account my.1password.com` reports the account is not signed in.
- No matching `op signin`, `safe-op`, `ibkr-gateway-reauth`, `ibkr-local ibc-config`, `ibgateway`, or `podman run` processes are running.
- Runtime directory state is minimal: `/run/user/1000/ibkr-local` and `/run/user/1000/ibkr-local/main-live` exist with `0700` permissions.

## What Is Implemented

- Local-only IBKR integration via `ibkr-local`; no hosted connector or MCP path is used.
- TWS/IBC live read-only login has previously completed through second factor and opened the TWS main window.
- IB Gateway is packaged through the shared TWS/Gateway Podman wrapper.
- Headless Gateway service exists as `ibkr-gateway-main-live.service`.
- Manual reauth helper exists as `ibkr-gateway-reauth-main-live`.
- Gateway uses normal login with `ReadOnlyApi=yes` and `SecondFactorDevice=IB Key`; Gateway does not support `ReadOnlyLogin=yes`.
- Live order mutation remains blocked by wrapper policy; `order-preview` remains preview-only.

## Recent Commits

- `9297a88 Add local IBKR TWS integration`
- `d3eaaf7 Add headless IB Gateway integration`
- `353150f Refine IB Gateway runtime setup`
- `e49f477 Harden IB Gateway reauth flow`

## Latest Fixes In HEAD

`e49f477` hardened the reauth path:

- Checks `op` and `safe-op` before auth work.
- Reuses an inherited valid `OP_SESSION_*` before prompting.
- Renders and validates the replacement `ibc.ini` before stopping an already-running Gateway service.
- Stops/installs/starts only after a valid replacement config exists.
- Redacts echoed `IbLoginId=` and `IbPassword=` in service logs if IBC ever prints config-like diagnostics.
- Updates OTP fallback docs so they do not show a bare OTP read that could print to a terminal.

## Current Blocker

The runtime test is blocked before Gateway startup by local 1Password desktop authorization.

Observed failures:

```text
ibkr-gateway-reauth-main-live -> authorization prompt dismissed
op signin --account my.1password.com >/dev/null -> authorization prompt dismissed
op whoami --account my.1password.com -> account is not signed in
```

Until the 1Password desktop prompt is approved/unlocked, the helper cannot render the private IBC config and Gateway will not start.

## Next Runtime Procedure

After unlocking or approving 1Password locally:

```bash
ibkr-gateway-reauth-main-live
```

Watch the service:

```bash
journalctl --user -u ibkr-gateway-main-live.service -f
```

Expected next state:

- helper renders `$XDG_RUNTIME_DIR/ibkr-local/main-live/ibc.ini` with mode `0600`;
- service starts `ibkr-local gateway --profile main-live --xvfb --ibc`;
- IBC selects `IB Key`;
- Gateway reaches the IBKR Mobile approval screen;
- user approves the IBKR Mobile notification.

Then run:

```bash
ibkr-local connect --profile main-live
ibkr-local positions --profile main-live
ibkr-local balances --profile main-live
ibkr-local executions --profile main-live
ibkr-local order-preview buy AAPL 1 --profile main-live --limit 100 --json
```

Do not use `--submit`, `submit`, `cancel`, or `modify`.

## Secret Handling Rules

- Keep all 1Password reads local through `safe-op` or the reauth helper.
- Do not print, echo, log, screenshot, redirect, or summarize passwords or OTPs.
- Do not override `XDG_RUNTIME_DIR`; 1Password desktop integration needs the real user runtime socket.
- If OTP fallback is needed, use a local helper or pipe directly into a local helper. Do not run a bare OTP read in a terminal.
- OTP ref, for local helper use only:

```text
op://3eyhyuvr6x6hvvajthxk5cn37u/3drrbjgoksyc3tuu4yxyvshjvq/one-time password?attribute=otp
```

## Verification To Re-run If Code Changes

```bash
bash -n packages/ibkr-local/ibkr-local.sh
bash -n packages/tws/wrapper.sh
git diff --check
nix build --no-link --print-out-paths .#homeConfigurations."xing@desktop".activationPackage -L
home-manager switch --flake .#xing@desktop
```

If no code changed since `e49f477`, start with the runtime procedure above.
