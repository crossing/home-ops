# IB Gateway runtime handoff

## Runtime layout

This is a Gateway-only runtime. `packages/ibgateway` contains the Podman image definition, installer wrapper, and IBC package. Home Manager generates `ibkr-gateway-reauth-PROFILE` and `ibkr-gateway-PROFILE.service` for each enabled credentialed profile.

Persistent per-profile paths are:

- Gateway installation: `${XDG_DATA_HOME:-$HOME/.local/share}/ibkr/PROFILE/gateway`
- Jts configuration: `${XDG_CONFIG_HOME:-$HOME/.config}/ibkr-local/jts/PROFILE`
- logs: `${XDG_STATE_HOME:-$HOME/.local/state}/ibkr-local/PROFILE`

The temporary IBC configuration is `$XDG_RUNTIME_DIR/ibkr-local/PROFILE/ibc.ini`. Its parent directories are private and the file mode is 0600. `ExecStopPost` removes the complete per-profile runtime directory.

The current Home Manager profile enables only `main-live`: live API port 4001, client ID 12, headless Xvfb display, and weekday authenticated restart at 11:45 PM. The configured but currently service-disabled profiles are `main-paper` on 4002, `pension-live` on 4003, and `pension-paper` on 4004. Generated IBC configuration applies each profile port through IBC 3.24.1's `OverrideTwsApiPort`, keeping the Gateway listener and client configuration aligned when another profile is enabled.

## Start and reauthenticate

Use the generated helper, not a direct service start:

```bash
ibkr-gateway-reauth-main-live
```

The helper requires an active `graphical-session.target`. It takes a nonblocking per-profile lock, obtains or reuses one process-scoped 1Password CLI session, and renders username and password through `safe-op`. It then unsets the scoped session before validating and installing the configuration. The token is not persisted, logged, placed in argv, or passed to the systemd user manager.

The authenticator step is deliberately manual. If prompted, complete the challenge in the Gateway UI. There is no command in this workflow that retrieves an authenticator code.

The helper stops an existing service and refuses to proceed if it remains active. It installs the runtime config, starts the service, and transfers ownership of that config only after systemd confirms the service is active. On a failed handoff, cleanup removes the runtime credentials unless a valid running service owns them. `ExistingSessionDetectedAction=secondary` prevents the new Gateway login from overriding another trading session: IBC 3.24.1 documents that the existing session continues and the newly started session terminates.

## Observe and stop

```bash
systemctl --user status ibkr-gateway-main-live.service
systemctl --user is-active ibkr-gateway-main-live.service
journalctl --user -u ibkr-gateway-main-live.service --since today
systemctl --user stop ibkr-gateway-main-live.service
```

After stopping, this should report that the runtime directory is absent:

```bash
test ! -e "$XDG_RUNTIME_DIR/ibkr-local/main-live"
```

The service has `Restart=no`, `KillMode=mixed`, and is part of the graphical session. A missed second-factor challenge exits instead of entering an automated relogin or systemd restart loop. The configured weekday IBC restart can maintain a valid authenticated session during the week, but it does not remove the realistic weekly/manual boundary: run the helper again after the weekend, an expired session, a timeout, or any broker-requested reauthentication.

## Read-only checks

After Gateway reports a ready API connection:

```bash
ibkr-local doctor --profile main-live
ibkr-local connect --profile main-live
ibkr-local positions --profile main-live
ibkr-local balances --profile main-live
ibkr-local order-preview buy AAPL 1 --profile main-live --limit 100 --json
```

The generated IBC config requires `ReadOnlyApi=yes`. Mutation arguments are rejected, and the order wrapper always adds preview mode. This is defense in depth; it is not authorization to test live submission.

## Rebuild and static verification

From the repository root:

```bash
bash -n packages/ibgateway/wrapper.sh packages/ibkr-local/ibkr-local.sh
nix eval --raw .#packages.x86_64-linux.ibgateway.name
nix eval --raw .#packages.x86_64-linux.ibkr-local.name
nix eval --raw '.#homeConfigurations."xing@desktop".config.systemd.user.services.ibkr-gateway-main-live.Service.Restart'
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibgateway -L
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibkr-local -L
nix build --no-link --print-out-paths '.#homeConfigurations."xing@desktop".activationPackage' -L
git diff --check
```

The only unavoidable legacy workstation text in the implementation is IBC's upstream `--tws-path` and `--tws-settings-path` option spelling. Those flags are required by IBC even when it is launched in Gateway mode; they do not indicate a workstation package or runtime.

## Remaining interactive test

No live authentication was performed during implementation. With the user present to unlock 1Password and manually complete the authenticator challenge:

1. Run `ibkr-gateway-reauth-main-live`.
2. Confirm `systemctl --user is-active ibkr-gateway-main-live.service` reports `active`.
3. Run `ibkr-local doctor --profile main-live`, `connect`, and one read-only data command.
4. Stop the service and confirm the runtime directory has been removed.

If the first run fails, inspect only sanitized service status/log output. Never print the generated IBC file, environment, credential references, or scoped session variables.
