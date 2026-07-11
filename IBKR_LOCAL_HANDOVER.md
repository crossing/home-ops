# Local IBKR integration handover

This branch provides a local-only, read-only Interactive Brokers integration built around IB Gateway, IBC, `ibkr-cli`, and `ibkr-local`. There is no workstation runtime or package in this integration.

## Architecture and safety boundary

- `packages/ibgateway` owns the Gateway container, installer wrapper, and packaged IBC release.
- `packages/ibkr-cli` provides account and market-data commands.
- `packages/ibkr-local` selects configured profiles, launches Gateway, renders ephemeral IBC configuration, and forces order commands into preview mode.
- `modules/home/ibkr-local` generates profile configuration, the per-profile start/reauth helper, and the Gateway user service.

The API is configured read-only. Mutation requests fail closed, and order preview remains preview-only. Username and password are read with `safe-op` during one process-scoped 1Password CLI session and written only to a mode-0600 file below `$XDG_RUNTIME_DIR`. The session token is unset immediately after rendering and is not passed to systemd or stored on disk. The authenticator code is never retrieved or automated: complete that challenge manually in the Gateway UI.

## Installed profiles and ports

The configured profiles are:

| Profile | Mode | API port | Gateway service |
| --- | --- | ---: | --- |
| `main-live` | live | 4001 | enabled |
| `main-paper` | paper | 4002 | not enabled |
| `pension-live` | live | 4003 | not enabled |
| `pension-paper` | paper | 4004 | not enabled |

Ports 4001 and 4002 are the normal live and paper defaults. The pension profiles use distinct ports so that future simultaneous instances cannot collide. Only `main-live` currently has credentials and a generated Gateway service/helper.

## Normal operation

After activating the Home Manager configuration and while the graphical user session is active, start or reauthenticate the configured profile with:

```bash
ibkr-gateway-reauth-main-live
```

Unlock or sign in to 1Password if prompted. When Gateway presents its authenticator challenge, approve or enter it manually in the Gateway UI. The helper serializes each profile's start operation, stops an existing instance, creates the ephemeral credential file, starts the service, and confirms that it became active.

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
ibkr-local order-preview buy AAPL 1 --profile main-live --limit 100 --json
```

## Authentication lifetime

Treat authentication as a weekly boundary, not a permanent unattended login. IBC requests an authenticated restart at 11:45 PM on weekdays, which is intended to carry a valid session through the trading week. A weekend reset, expired session, missed authenticator challenge, or broker-requested reauthentication requires running `ibkr-gateway-reauth-main-live` again and completing the authenticator step manually.

If second-factor authentication times out, IBC exits after the bounded timeout path. The user service has `Restart=no`, so it does not create repeated prompts. The service is also tied to `graphical-session.target`; it is not intended to outlive the user's graphical session.

## Remaining live verification

Build and evaluation checks pass, but no live Gateway login was performed during implementation. With the user present and 1Password unlocked, the remaining test is to run the reauth helper, manually complete the authenticator challenge, confirm the service stays active, then run `doctor`, `connect`, and one read-only data command. Finally stop the service and confirm `$XDG_RUNTIME_DIR/ibkr-local/main-live` is removed. Do not expose credential material or session tokens while diagnosing the run.

See `HANDOFF-ibkr-gateway-runtime.md` for paths, lifecycle details, and verification commands.
