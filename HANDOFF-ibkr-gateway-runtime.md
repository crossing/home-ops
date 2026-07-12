# IB Gateway runtime handoff

## Paused dual-live continuation: 2026-07-12

Branch: `feature/ibkr-local-integration`. The dual-instance work is committed through `7322793`:

- `50fbed0` adds the tested, idempotent `ibkr-gateway-ensure-live` coordinator.
- `7322793` enables `pension-live` beside `main-live` using the existing modular service/reauth generator.
- Design and implementation plan are committed as `f93c085` and `ca98046` under `docs/superpowers/`.

`pension-live` uses port 4003, client ID 22, a deterministic `ibkr-gateway-pension-live` container, and the 1Password Login item identified by username `crossing2pension`. Only stable `op://` item references are committed. The aggregate command checks `main-live` then `pension-live`, leaves active services untouched, and invokes only the missing profile's existing reauthentication helper. A second invocation against two active services performed no reauthentication.

### Verification completed

- The coordinator shell test passed all four cases: both active, pension missing, both missing, and one helper failing while the other still starts.
- Both Gateway profiles evaluate with `Restart=no`; `gateway.ensureProfiles` evaluates to `["main-live","pension-live"]`.
- `ibgateway`, `ibkr-local`, and the full `xing@desktop` Home Manager activation package built successfully.
- The coordinator from the built Home Manager generation passed the same fake-systemd test.
- Shell syntax, `git diff --check`, and the existing fail-closed `order-preview ... --submit` check passed.
- Live orchestration skipped the already-active `main-live` instance. Its invocation ID remained `8322c9a7c37e4f9f94ed9e1b36a7d85f` throughout.
- The pension helper filled the verified `crossing2pension` username/password, reached `Second Factor Authentication`, and offered phone-notification authentication. The screen reported `Notification sent`; two local resend attempts did not produce a phone challenge.

### Pause state and cleanup

The incomplete pension instance was stopped cleanly. `ibkr-gateway-pension-live.service` is inactive, its private runtime directory is absent, port 4003 is closed, and no pension Gateway container remains. `main-live` remains active on its original invocation. The persistent 1Password shell was exited.

Normal Home Manager activation was attempted only after the full build passed, but stopped at the pre-existing manually linked `~/.config/systemd/user/ibkr-gateway-main-live.service` conflict before systemd reload. For the runtime proof, only the new pension unit was linked from the verified generation and `systemctl --user daemon-reload` was run. The aggregate and pension reauth commands are present in this verified generation but are not yet installed into the normal Home Manager path:

```text
/nix/store/nm807cwvlgiddrmqhl8r0vj6wwvmnivw-home-manager-generation
```

### Resume after checking the pension device

1. Confirm that `crossing2pension` has a working IBKR Mobile/IB Key device and that phone notifications or in-app pending authentication are enabled.
2. Resolve the Home Manager link conflict or continue temporarily with the verified generation's `home-path/bin` prepended to `PATH`.
3. In one persistent terminal shell, run `op signin --account my.1password.com`, verify `op whoami`, then run `ibkr-gateway-ensure-live`.
4. Confirm output says `main-live: already active` and starts only `pension-live`; approve the pension IB Key challenge.
5. Require `Login has completed`, port 4003 listening, and `ibkr-local connect --profile pension-live` succeeding before treating the pension instance as authenticated.
6. Run the aggregate command again and confirm both profiles report `already active` with unchanged invocation IDs.
7. Perform only sanitized row-count checks for pension positions, balances, and executions; do not print account IDs or financial rows.

## Completed runtime proof: 2026-07-12

Branch: `feature/ibkr-local-integration`. Last verified code commit before this continuation: `d0d4100`. The completed continuation changes are in:

- `modules/home/ibkr-local/default.nix`
- `packages/ibgateway/Dockerfile`
- `packages/ibgateway/wrapper.sh`

Current runtime is intentionally live: `ibkr-gateway-main-live.service` is active, exactly one named Gateway container is running, and port 4001 is listening. The latest Home Manager activation package builds successfully.

### What was proved today

- Xvfb itself works. With exactly one Gateway container, headless login completed, port 4001 listened, three accounts connected, positions/balances/executions returned data, and an AAPL LMT what-if returned `preview_only=true`.
- `ReadOnlyApi=no` is required for IBKR what-if previews; the constrained CLI still blocks `--submit` and does not expose cancel/modify.
- The apparent Xvfb/API failures came from nine orphaned Gateway containers accumulated by earlier service stops, not from Xvfb. Those containers were stopped and removed.
- Container-local `xdotool`/`scrot` confirmed that the authenticated main frame reported the API server connected. They remain in the image for local Java UI diagnostics.
- IBC `ENABLEAPI` is invalid for IB Gateway. The temporary command-server experiment was removed and is not present in the worktree.

### Final cleanup and live proof

The wrapper gives each service a deterministic container name, adds cleanup traps to both the inner IBC runner and outer Xvfb layer, and sets systemd `KillMode=process` so systemd does not kill conmon before Podman cleanup. The final stop proof ended with the unit `inactive/dead` and `Result=success`, removed the named container and private runtime directory, and closed port 4001. Exit status 143 is explicitly accepted as a successful signal-driven shutdown.

The helper tries ordinary idempotent `op signin` first and uses a raw scoped-session fallback only for non-app-integrated CLI sessions. 1Password authorization remains scoped to the user's terminal process tree; run both `op signin` and the reauthentication helper in that terminal rather than a Codex PTY.

After the cleanup proof, a fresh authenticated start completed successfully. Exactly one named container remains running, the service is active, port 4001 listens, the runtime credential file is mode 0600, and no `OP_SESSION_*` or `OP_ACCOUNT` variable reached the service environment. Sanitized API checks returned three managed accounts, 33 position rows, 8 balance rows, zero execution rows, and an AAPL LMT what-if with `preview_only=true` and status `PreSubmitted`. Submit remains blocked.

The full Home Manager activation build passed, but activation later encountered an unrelated pre-existing link conflict at `~/.agents/skills/incremental-editing`. That directory was left untouched; the freshly built IBKR unit was linked and reloaded directly for the runtime proof.

## Live verification: 2026-07-11

`main-live` is verified end to end. The app-integrated 1Password CLI authorized the helper without a reusable raw token, IBC filled username/password, the user completed the IBKR-offered second-factor flow, and IBC logged `Login has completed`. Gateway listens on port 4001 with API write access enabled solely to permit constrained what-if previews.

Sanitized checks passed: TCP/API connectivity across three managed accounts; 33 position rows; 8 balance-summary rows; zero execution rows; and an AAPL LMT what-if marked `preview_only=true` with status `PreSubmitted`. `--submit` remains blocked, while cancel and modify are not exposed. The service stayed active after preview, its credential file is mode 0600, and no `OP_SESSION_*` or `OP_ACCOUNT` reached its environment.

The verified service now runs under Xvfb with no visible Java window. The available IBKR second-factor flow is completed externally when requested; the 1Password OTP field is not used. Trust `Login has completed`, port 4001, and `ibkr-local connect` as health signals.

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

The second-factor step is deliberately manual. The live test exposed no authenticator-code option; complete the IBKR challenge manually using the method Gateway offers. The 1Password OTP field is not read or automated.

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
ibkr-local order-preview buy AAPL 1 --profile main-live --type LMT --limit 100 --json
```

`main-live` sets `ReadOnlyApi=no` because IBKR requires API write access even for what-if order previews. The constrained wrapper still rejects submit, cancel, and modify operations and always adds preview mode. Do not bypass `ibkr-local` with the upstream CLI.

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

## Next repository step

The runtime work is ready for review. Do not print the generated IBC file, environment, credential references, or scoped session variables during any follow-up verification.
