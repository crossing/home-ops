# Local IBKR integration handover

## Verified live state

On 2026-07-11, `main-live` completed real Gateway authentication and API verification. IBC applied port 4001 and `ReadOnlyApi=no`; the constrained CLI returned healthy connectivity for three accounts, 33 position rows, 8 balance-summary rows, zero execution rows, and a successful AAPL LMT what-if marked `preview_only=true`. Submit remained blocked and cancel/modify remained unavailable. The service remained active with its credential file at mode 0600 and no 1Password authentication variables in its environment.

The minimized Java window may retain a stale login-screen image despite the authenticated API state. Do not close it: closing the Gateway window stops IBC and the user service. Use `ibkr-local connect --profile main-live` and the service journal as the health source of truth.

This branch provides a local-only Interactive Brokers integration built around IB Gateway, IBC, `ibkr-cli`, and the constrained `ibkr-local` interface. There is no workstation runtime or package in this integration.

## Architecture and safety boundary

- `packages/ibgateway` owns the Gateway container, installer wrapper, and packaged IBC release.
- `packages/ibkr-cli` provides account and market-data commands.
- `packages/ibkr-local` selects configured profiles, launches Gateway, renders ephemeral IBC configuration, and forces order commands into preview mode.
- `modules/home/ibkr-local` generates profile configuration, the per-profile start/reauth helper, and the Gateway user service.

`main-live` enables Gateway API write access because IBKR requires it for what-if previews, but `ibkr-local` rejects submit, cancel, and modify operations and forces order requests into preview mode. Username and password are read with `safe-op` during one process-scoped 1Password CLI session and written only to a mode-0600 file below `$XDG_RUNTIME_DIR`. Any session token is unset immediately after rendering and is not passed to systemd or stored on disk. The live test exposed no authenticator-code option; the 1Password OTP field remains unused and the offered IBKR second-factor challenge is completed manually.

## Installed profiles and ports

The configured profiles are:

| Profile | Mode | API port | Gateway service |
| --- | --- | ---: | --- |
| `main-live` | live | 4001 | enabled |
| `main-paper` | paper | 4002 | not enabled |
| `pension-live` | live | 4003 | not enabled |
| `pension-paper` | paper | 4004 | not enabled |

Ports 4001 and 4002 are the normal live and paper defaults. Each generated IBC config sets `OverrideTwsApiPort` to its profile port, so the pension profiles' distinct 4003/4004 client settings also become the corresponding Gateway listener settings when those services are enabled. Only `main-live` currently has credentials and a generated Gateway service/helper.

## Normal operation

After activating the Home Manager configuration and while the graphical user session is active, start or reauthenticate the configured profile with:

```bash
ibkr-gateway-reauth-main-live
```

Unlock or sign in to 1Password if prompted. When Gateway presents its authenticator challenge, approve or enter it manually in the Gateway UI. The helper serializes each profile's start operation, stops an existing instance, creates the ephemeral credential file, starts the service, and confirms that it became active. IBC is configured with `ExistingSessionDetectedAction=secondary`: under IBC 3.24.1 semantics, if another trading session already exists, that existing session continues and this newly started Gateway session terminates rather than displacing it.

Inspect or stop the service with:

```bash
systemctl --user status ibkr-gateway-main-live.service
journalctl --user -u ibkr-gateway-main-live.service --since today
systemctl --user stop ibkr-gateway-main-live.service
```

The runtime credential directory is removed after the service stops. Do not start the generated service directly when no valid runtime configuration exists; use the reauth helper.

Once the API connection is ready, safe examples are:

```bash
ibkr-local doctor --profile main-live
ibkr-local connect --profile main-live
ibkr-local positions --profile main-live
ibkr-local balances --profile main-live
ibkr-local order-preview buy AAPL 1 --profile main-live --type LMT --limit 100 --json
```

## Authentication lifetime

Treat authentication as a weekly boundary, not a permanent unattended login. IBC requests an authenticated restart at 11:45 PM on weekdays, which is intended to carry a valid session through the trading week. A weekend reset, expired session, missed authenticator challenge, or broker-requested reauthentication requires running `ibkr-gateway-reauth-main-live` again and completing the authenticator step manually.

If second-factor authentication times out, IBC exits after the bounded timeout path. The user service has `Restart=no`, so it does not create repeated prompts. The service is also tied to `graphical-session.target`; it is not intended to outlive the user's graphical session.

## Remaining live verification

Build and evaluation checks pass, but no live Gateway login was performed during implementation. With the user present and 1Password unlocked, the remaining test is to run the reauth helper, manually complete the authenticator challenge, confirm the service stays active, then run `doctor`, `connect`, and one read-only data command. Finally stop the service and confirm `$XDG_RUNTIME_DIR/ibkr-local/main-live` is removed. Do not expose credential material or session tokens while diagnosing the run.

See `HANDOFF-ibkr-gateway-runtime.md` for paths, lifecycle details, and verification commands.
