# IBKR Local Integration Handover

Date: 2026-07-05
Branch: `feature/ibkr-local-integration`

## Current State

This branch contains the local-only Interactive Brokers integration. It implements the local `ibkr-cli` plus TWS/IBC path; no MCP or hosted connector integration is used.

The important files are:

- `packages/ibgateway/default.nix`
- `packages/ibkr-local/default.nix`
- `packages/ibkr-local/ibkr-local.sh`
- `packages/ibkr-local/test-ibc-login.sh`
- `modules/home/ibkr-local/default.nix`
- `homes/x86_64-linux/xing@desktop/default.nix`
- `homes/x86_64-linux/xing@desktop/ibkr.nix`
- `packages/tws/Dockerfile`
- `packages/tws/common.nix`
- `packages/tws/default.nix`
- `packages/tws/wrapper.sh`

The live read-only TWS login test completes for the `crossing2p` IBKR item: IBC reaches the second-factor dialog, clicks `Enter Read Only`, logs `Login has completed`, and opens the TWS main window.

The live Gateway runtime path now starts under the Home Manager user service and reaches the IBKR Mobile 2FA approval screen. Gateway does not support IBC `ReadOnlyLogin=yes`; the service now uses a normal Gateway login with `ReadOnlyApi=yes`, `SecondFactorDevice=IB Key`, and the existing `ibkr-local` wrapper-level live-order blocks. API checks are still unverified because the latest run was left waiting for IBKR Mobile approval and was then stopped cleanly.

## Implemented

- Added `packages/ibkr-local`, exposing `ibkr-local`, `tws`, and `ibgateway`.
- Added `packages/ibgateway`, which packages IB Gateway through the same shared Podman/IBC wrapper as TWS.
- Refactored `packages/ibkr-local/default.nix` to reuse Snowfall-discovered sibling packages through `pkgs.${namespace}` instead of self-instantiating `../ibkr-cli` or `../tws` with `pkgs.callPackage`.
- Deliberately does not expose raw upstream `ibkr` from `ibkr-local`, so the constrained wrapper is not bypassed by this package.
- Added JSON-first wrapper commands:
  - `doctor`
  - `connect`
  - `positions`
  - `balances`
  - `executions`
  - `flex-trades`
  - `transfers`
  - `dividends`
  - `order-preview`
  - `config path`
  - `config show`
  - `tws`
  - `gateway`
  - `automation-smoke`
  - `ibc-config`
- Added `programs.ibkrLocal` Home Manager module under `modules/home/ibkr-local/default.nix`.
- Added desktop-specific profiles under `homes/x86_64-linux/xing@desktop/ibkr.nix`:
  - `main-paper`: port `7497`, client id `11`
  - `main-live`: port `7496`, client id `12`
  - `pension-paper`: port `7507`, client id `21`
  - `pension-live`: port `7506`, client id `22`
- Imported `./ibkr.nix` from `homes/x86_64-linux/xing@desktop/default.nix`.
- Added account group placeholders for `margin`, `cash`, `isa`, and `pension`.
- Generated local config files through Home Manager:
  - `~/.config/ibkr-local/profiles.json`
  - `~/.config/ibkr-local/ibkr-cli/config.toml`
- Hardened `packages/tws/wrapper.sh`:
  - strict shell mode
  - shared TWS/IB Gateway wrapper configuration through `packages/tws/common.nix`
  - separate display mode from app mode, so `--xvfb --ibc` works
  - explicit `--visible`, `--x11`, `--xvfb`, and `--ibc` support
  - `TWS_DIR`, `CONFIG_DIR`, and `TWS_LOG_DIR` support for TWS
  - `IBGATEWAY_DIR`, `IBGATEWAY_CONFIG_DIR`, and `IBGATEWAY_LOG_DIR` support for IB Gateway
  - Gateway IBC detection accepts both `ibgateway/<version>/jars` and direct `<version>/jars` under the configured Gateway install directory
  - direct-root Gateway installs are mounted in the container as `/opt/ibgateway/latest`, matching IBC's expected Gateway path shape
  - Gateway install marker detection uses the direct `ibgateway` launcher, so the wrapper does not reinstall Gateway every run
  - `ibgateway.vmoptions` is patched to the current in-container path before launch
  - JxBrowser key output is masked in service logs
  - `/dev/dri` is mounted only when it exists
  - in-container JTS path is consistently `/home/tws/Jts`
  - `xvfb-run` added to the TWS package runtime inputs
- Added headless IB Gateway Home Manager support:
  - `programs.ibkrLocal.gateway.enable`
  - per-profile `ibkr-gateway-<profile>.service` user services
  - per-profile `ibkr-gateway-reauth-<profile>` scripts installed into the home profile
  - `main-live` is configured for normal Gateway login via 1Password refs, `ReadOnlyApi=yes`, and `SecondFactorDevice=IB Key`
  - the service is not wanted by `default.target`; it is manually started by the reauth script
  - the service is tied to `graphical-session.target` with `PartOf`, so it stops with the graphical login session even when user linger is enabled
  - the service reads only an already-rendered runtime `ibc.ini`; 1Password access happens only in the manual reauth script
- Added `packages/ibkr-local/test-ibc-login.sh`:
  - defaults to `main-live`
  - validates the 1Password item username with `safe-op read`
  - renders the IBC config through `safe-op read` secret refs
  - verifies generated config path, mode `0600`, and `TradingMode`
  - supports `--read-only-login`, which renders and verifies `ReadOnlyLogin=yes`
  - refuses paper mode unless `--allow-paper` is passed
  - sanitizes username, password, and JxBrowser key from logs
  - reports `logged-in` before `2fa` when both strings are present in the same read-only login log
- IBC is packaged inside `packages/tws/default.nix`:
  - pinned to IBC `3.24.1`
  - fetched from the upstream `IBCLinux-3.24.1.zip` release
  - mounted into the TWS container as `/opt/ibc` when `tws --ibc` is used
  - not exposed as a separate top-level `ibc` executable

## Safety Constraints

- v1 is read-only plus what-if order preview only.
- `ibkr-local order-preview` always appends upstream `--preview`.
- `--submit`, `submit`, `cancel`, and `modify` are blocked by the wrapper.
- `order-preview --account ACCOUNT` is forwarded to upstream `ibkr buy/sell --account ACCOUNT`.
- `ibc-config` refuses to read secrets unless `safe-op` is available.
- `ibc-config` reads username/password through `safe-op read op://... --no-newline`; it does not call raw `op`.
- `ibc-config --read-only-login` adds `ReadOnlyLogin=yes`; without the flag, the generated IBC config stays on the normal login path.
- `ibc-config --second-factor-device VALUE` adds `SecondFactorDevice=VALUE`.
- Gateway does not support `ReadOnlyLogin=yes`; use `ReadOnlyApi=yes` plus wrapper-level order mutation blocks for v1.
- The Gateway service itself does not call `op` or `safe-op`; `ibkr-gateway-reauth-main-live` renders the ephemeral IBC config first, then starts the service.
- The Gateway runtime credential config lives under `$XDG_RUNTIME_DIR/ibkr-local/main-live/ibc.ini` with mode `0600`.
- The login test keeps the IBC credential config under a private temp runtime directory and deletes it on exit.
- Do not override `XDG_RUNTIME_DIR` for 1Password secret reads; that breaks desktop-app socket discovery. Use `IBKR_IBC_RUNTIME_PARENT` for IBC config placement instead.
- No secrets are written to Nix-managed files.
- Home Manager activation was run on 2026-07-05 to install and test `ibkr-gateway-main-live.service`.

## 1Password Metadata

Non-secret identifiers used for the successful test:

- Item id: `3drrbjgoksyc3tuu4yxyvshjvq`
- Vault id: `3eyhyuvr6x6hvvajthxk5cn37u`
- Username field: `username`
- Password field: `password`
- OTP field label observed in metadata: `one-time password`

Treat the OTP as a secret. This is a fallback path only if the user wants to avoid the IBKR Mobile push approval path. The OTP ref is:

```text
op://3eyhyuvr6x6hvvajthxk5cn37u/3drrbjgoksyc3tuu4yxyvshjvq/one-time password?attribute=otp
```

Never print the OTP. Verify only with a pipe such as `safe-op read "$TOTP_REF" --no-newline | wc -c`, or pass it directly to a local UI automation helper that does not log it.

## Verification Run

These passed on 2026-07-04:

```bash
bash -n packages/ibkr-local/test-ibc-login.sh
bash -n packages/ibkr-local/ibkr-local.sh
bash -n packages/tws/wrapper.sh
git diff --cached --check
git diff --check
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibkr-local -L
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibgateway -L
nix build --no-link --print-out-paths .#packages.x86_64-linux.tws -L
nix build --no-link --print-out-paths .#homeConfigurations."xing@desktop".activationPackage -L
nix eval --raw .#pkgs.x86_64-linux.nixpkgs.internal.ibkr-local.name
nix eval --raw .#pkgs.x86_64-linux.nixpkgs.internal.ibgateway.name
nix eval --json .#packages.x86_64-linux.ibgateway.name
nix eval --json .#packages.x86_64-linux --apply builtins.attrNames
nix eval --json '.#homeConfigurations."xing@desktop".config.programs.ibkrLocal.gateway.enable'
nix eval --json '.#homeConfigurations."xing@desktop".config.systemd.user.services."ibkr-gateway-main-live".Unit.PartOf'
nix eval --json '.#homeConfigurations."xing@desktop".config.systemd.user.services."ibkr-gateway-main-live".Service'
packages/ibkr-local/test-ibc-login.sh --render-only --item-id 3drrbjgoksyc3tuu4yxyvshjvq
packages/ibkr-local/test-ibc-login.sh --read-only-login --duration 300 --item-id 3drrbjgoksyc3tuu4yxyvshjvq
```

Latest successful package paths:

```text
/nix/store/bhg2c39wb771qklw9gg3kk8wqayw64y3-ibkr-local
/nix/store/izm3ym1px4q6a6hzg1fpggmk6mrhxsj1-ibgateway
/nix/store/cy7xh33mp5rzap3nqjbr5b3f5jfcxhmg-tws
/nix/store/wnvmknzpbdcphh0rsxkdjjvvpdyqbk8x-home-manager-generation
```

Full live launch command used:

```bash
packages/ibkr-local/test-ibc-login.sh --read-only-login --duration 300 --item-id 3drrbjgoksyc3tuu4yxyvshjvq
```

Observed evidence:

- TWS installed under `~/.local/share/ibkr/main-live/tws`.
- IBC started with `TradingMode=live`, `ReadOnlyApi=yes`, and `ReadOnlyLogin=yes`.
- IBC reached `Second Factor Authentication`, clicked `Enter Read Only`, and logged `Login has completed`.
- TWS opened the main window titled `All Interactive Brokers`.
- The managed test runner was stopped after recording successful read-only login.
- No TWS/podman test processes remained afterward.
- No `ibkr-ibc*` or `ibkr-ibc-test*` temp credential directories remained afterward.

Current headless Gateway service evidence from eval/build:

- `ibkr-gateway-main-live.service` has `PartOf=["graphical-session.target"]`.
- `ExecCondition` checks `systemctl --user -q is-active graphical-session.target`.
- `Restart="no"`.
- There is no `Install` attr, so the service is not auto-started from `default.target`.
- `ExecStopPost` removes `%t/ibkr-local/main-live`.
- The generated run script executes `ibkr-local gateway --profile main-live --xvfb --ibc`.
- The generated reauth script stops the service, checks `graphical-session.target`, gets a scoped raw `op signin` session token, exports the matching `OP_SESSION_*` variable only around `ibkr-local ibc-config`, unsets that session token immediately after render, validates the rendered config, installs it at mode `0600`, then starts the service.

## Gateway Runtime Attempt: 2026-07-05

Additional checks passed:

```bash
bash -n packages/ibkr-local/ibkr-local.sh
bash -n packages/tws/wrapper.sh
git diff --check
nix eval --json '.#homeConfigurations."xing@desktop".config.programs.ibkrLocal.gateway.profiles.main-live'
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibgateway -L
nix build --no-link --print-out-paths .#packages.x86_64-linux.ibkr-local -L
nix build --no-link --print-out-paths .#homeConfigurations."xing@desktop".activationPackage -L
home-manager switch --flake .#xing@desktop
```

Latest successful package paths from this run:

```text
/nix/store/iw3r3f6x0w6xi9maj9kla99g9p3gi2gz-ibgateway
/nix/store/lhi4xdsx6ip1h7hn7wdf83g4v70ln27r-ibkr-local
/nix/store/r7vxzbspfq2aaix2a2nyym5by14vg7bz-home-manager-generation
```

Runtime findings:

- Earlier testing used a single persistent shell for `op signin`, secret ref byte-count checks, and `ibkr-gateway-reauth-main-live`. The current intended flow is helper-owned: `ibkr-gateway-reauth-main-live` gets its own scoped raw `OP_SESSION_*` token and carries it through the `safe-op` render call so child processes do not need a second 1Password authorization.
- The original `op://Private/...` refs failed for this item; switching to vault id `3eyhyuvr6x6hvvajthxk5cn37u` fixed username/password reads.
- The first Gateway service run installed Gateway under `~/.local/share/ibkr/main-live/gateway`, but the wrapper failed to detect the direct-root layout. The package now mounts it as `/opt/ibgateway/latest`, and `ibgateway --screenshot-only` passed against the existing install.
- With `ReadOnlyLogin=yes`, IBC logged `Read-only login not supported by Gateway`.
- With `ReadOnlyLogin` off and `SecondFactorDevice=IB Key`, IBC rendered settings with `ReadOnlyApi=yes`, `SecondFactorDevice=IB Key`, and `TradingMode=live`; it clicked through to the phone approval path and logged `Second Factor Authentication initiated`.
- Screenshot proof at `/tmp/ibgateway-2fa.png` showed `Open the IBKR notification on your phone`, `Notification sent`, and Gateway status `disconnected`.
- Five `ibkr-local connect --profile main-live` probes returned connection refused on `127.0.0.1:7496` while Gateway waited for mobile approval.
- An OTP fallback read using `safe-op read ".../one-time password?attribute=otp" --no-newline | wc -c` was attempted only as a byte-count check, but 1Password requested another authorization and the prompt was dismissed; no OTP was printed or used.
- The pending Gateway service was stopped afterward. `ibkr-gateway-main-live.service` was inactive, and `%t/ibkr-local/main-live` was removed; only the empty `%t/ibkr-local` base directory remained.

Follow-up on 2026-07-05:

- The reauth helper was changed back to a scoped raw-session flow: it calls `op signin --raw`, tests candidate `OP_SESSION_*` names with `op whoami`, exports the matching variable only for the `ibkr-local ibc-config` render, then unsets it before validating and installing the config.
- A sidecar review found three runtime safety issues, now fixed:
  - the helper checks `op` and `safe-op` before auth work;
  - it reuses an inherited valid `OP_SESSION_*` before prompting with `op signin --raw`;
  - it renders and validates the replacement `ibc.ini` before stopping an already-running Gateway service, then stops/installs/starts only after the replacement config is ready.
- Service log sanitization now also redacts echoed `IbLoginId=` and `IbPassword=` lines if IBC ever prints config-like diagnostics.
- The OTP fallback notes no longer show a bare `safe-op read` command that could be copy-pasted into a terminal and print an OTP.
- The updated helper was built and activated with `home-manager switch --flake .#xing@desktop`.
- Latest activation package build path after the delayed-stop/session-reuse fix: `/nix/store/qzi31hwbsq8m6ypm7qbkkbd3q36k06ms-home-manager-generation`.
- The installed helper path after activation was `/nix/store/pnwjq2n3pw5h7pdh5lxx7rdsj76www9w-ibkr-gateway-reauth-main-live/bin/ibkr-gateway-reauth-main-live`.
- Runtime retry after activation still did not reach Gateway startup because 1Password desktop dismissed the authorization prompt. A non-raw `op signin --account my.1password.com` attempt with stdout discarded was also dismissed. `op whoami --account my.1password.com` still reports the account is not signed in.
- A subsequent `ibkr-gateway-reauth-main-live` retry at 2026-07-05 21:40 also failed before Gateway startup with `authorization prompt dismissed`; cleanup left the service inactive and no matching auth/Gateway processes running.
- Current runtime state after the failed authorization attempts: `ibkr-gateway-main-live.service` is inactive and no Gateway/TWS/Podman runtime process is running.

## Next Step: Complete Gateway 2FA and API Checks

Goal: complete the first live IB Gateway login through `ibkr-gateway-reauth-main-live`, then confirm the local API path supports the v1 operations: `connect`, `positions`, `balances`, `executions`, and `order-preview --preview`.

Gateway startup is runtime-tested through the IBKR Mobile 2FA approval prompt. API checks are still pending because the latest run did not receive the mobile approval.

Recommended shape:

1. If code changed since the last activation, rebuild and activate Home Manager first:

```bash
home-manager switch --flake .#xing@desktop
```

Otherwise continue from the installed generation.

2. Start/restart Gateway with manual reauth from a single local terminal session:

```bash
ibkr-gateway-reauth-main-live
```

Confirm from the user journal that `ibkr-gateway-main-live.service` starts, selects `IB Key`, and reaches the mobile approval state:

```bash
journalctl --user -u ibkr-gateway-main-live.service -f
```

Approve the IBKR Mobile notification when it arrives. Then run API checks against `main-live`:

```bash
ibkr-local connect --profile main-live
ibkr-local positions --profile main-live
ibkr-local balances --profile main-live
ibkr-local executions --profile main-live
```

4. Check whether upstream what-if preview works through Gateway:

```bash
ibkr-local order-preview buy AAPL 1 --profile main-live --limit 100 --json
```

5. Keep live order mutation blocked. Do not use `--submit`, `submit`, `cancel`, or `modify`.

## Fallback: Avoid IB Key Push

Only do this if the user wants to avoid the IBKR Mobile push path. The OTP path was not completed on 2026-07-05 because 1Password required another authorization. If needed, keep the work in one local shell, authorize `op` immediately before reading OTP, select the correct second-factor path if needed, and fill/submit the code without exposing it in logs or chat.

Recommended shape:

1. Add a Gateway-specific local helper under `packages/ibkr-local/` that can attach to the Gateway Xvfb display owned by `ibkr-gateway-main-live.service`.
2. Use `wmctrl`/`xdotool`, screenshots, or Java accessibility only for local window discovery and typing.
3. Read the OTP inside that local helper or pipe it directly into that helper:

```bash
safe-op read "$TOTP_REF" --no-newline | local-gateway-otp-helper --stdin
```

where `TOTP_REF` is:

```text
op://3eyhyuvr6x6hvvajthxk5cn37u/3drrbjgoksyc3tuu4yxyvshjvq/one-time password?attribute=otp
```

4. Do not pass the OTP through model-visible tool arguments.
5. Do not print, screenshot, echo, redirect, or log the OTP.
6. Emit sanitized state only, such as `selected second factor device`, `filled otp field`, or `submitted otp`.
7. Keep `op signin` and all `safe-op read` calls in the same local shell/app authorization window when possible.

Open questions for the next pass:

- Whether the `IB Key` path expects an app approval rather than a typed TOTP.
- Whether the Gateway `Mobile Authenticator app` or challenge/response link exposes a code input that can be filled locally.
- Whether Gateway's Xvfb UI is easier to drive through `xdotool` key events or Java accessibility.

## Rollback Notes

Home Manager was activated during the 2026-07-05 Gateway runtime test. To inspect or roll back generations:

```bash
home-manager generations
```

Build before switching:

```bash
nix build .#homeConfigurations."xing@desktop".activationPackage -L
```

If a post-activation smoke check fails, roll back to the recorded generation using the matching Home Manager generation path from `home-manager generations`.
