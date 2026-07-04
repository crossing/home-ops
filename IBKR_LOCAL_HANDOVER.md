# IBKR Local Integration Handover

Date: 2026-07-04
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

The live read-only login test now completes for the `crossing2p` IBKR item: IBC reaches the second-factor dialog, clicks `Enter Read Only`, logs `Login has completed`, and opens the TWS main window. Full 2FA code entry is not automated yet; the earlier non-read-only run reached the expected second-factor prompt.

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
  - in-container JTS path is consistently `/home/tws/Jts`
  - `xvfb-run` added to the TWS package runtime inputs
- Added headless IB Gateway Home Manager support:
  - `programs.ibkrLocal.gateway.enable`
  - per-profile `ibkr-gateway-<profile>.service` user services
  - per-profile `ibkr-gateway-reauth-<profile>` scripts installed into the home profile
  - `main-live` is configured for read-only Gateway login via 1Password references
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
- The Gateway service itself does not call `op` or `safe-op`; `ibkr-gateway-reauth-main-live` renders the ephemeral IBC config first, then starts the service.
- The Gateway runtime credential config lives under `$XDG_RUNTIME_DIR/ibkr-local/main-live/ibc.ini` with mode `0600`.
- The login test keeps the IBC credential config under a private temp runtime directory and deletes it on exit.
- Do not override `XDG_RUNTIME_DIR` for 1Password secret reads; that breaks desktop-app socket discovery. Use `IBKR_IBC_RUNTIME_PARENT` for IBC config placement instead.
- No secrets are written to Nix-managed files.
- No Home Manager activation has been run.

## 1Password Metadata

Non-secret identifiers used for the successful test:

- Item id: `3drrbjgoksyc3tuu4yxyvshjvq`
- Vault id: `3eyhyuvr6x6hvvajthxk5cn37u`
- Username field: `username`
- Password field: `password`
- OTP field label observed in metadata: `one-time password`

Treat the OTP as a secret. This should now be a fallback path only if read-only login cannot support the required local API operations. If it is needed, prefer:

```bash
safe-op read "op://3eyhyuvr6x6hvvajthxk5cn37u/3drrbjgoksyc3tuu4yxyvshjvq/one-time password?attribute=otp" --no-newline
```

Never print the OTP. Verify only with a pipe such as `wc -c`, or pass it directly to a local UI automation helper that does not log it.

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
- The generated reauth script stops the service, checks `graphical-session.target`, runs `op signin`, renders IBC config through `ibkr-local ibc-config`, installs it at mode `0600`, then starts the service.

## Next Step: Test Headless Gateway Login and API

Goal: test the first live IB Gateway login through `ibkr-gateway-reauth-main-live`, then confirm the local API path supports the v1 operations: `connect`, `positions`, `balances`, `executions`, and `order-preview --preview`.

Gateway login itself has not been runtime-tested yet. The successful read-only login evidence above is for TWS; Gateway has only been verified by package builds, Home Manager eval/build, generated service inspection, and script syntax checks.

Recommended shape:

1. Activate the Home Manager generation when ready:

```bash
home-manager switch --flake .#xing@desktop
```

2. Start/restart Gateway with manual reauth:

```bash
ibkr-gateway-reauth-main-live
```

Confirm from the user journal that `ibkr-gateway-main-live.service` starts and reaches an IBC read-only login state before running API checks:

```bash
journalctl --user -u ibkr-gateway-main-live.service -f
```

3. Run read-only API checks against `main-live`:

```bash
ibkr-local connect --profile main-live
ibkr-local positions --profile main-live
ibkr-local balances --profile main-live
ibkr-local executions --profile main-live
```

4. Check whether upstream what-if preview works in a Gateway read-only login:

```bash
ibkr-local order-preview buy AAPL 1 --profile main-live --limit 100 --json
```

5. Keep live order mutation blocked. Do not use `--submit`, `submit`, `cancel`, or `modify`.

## Fallback: Fill 2FA From 1Password

Only do this if the read-only login cannot support the required local API operations. If needed, when TWS reaches the `Second Factor Authentication` window, read the current OTP locally through `safe-op`, select the correct second-factor path if needed, and fill/submit the code without exposing it in logs or chat.

Recommended shape:

1. Add a local helper owned by `packages/ibkr-local/test-ibc-login.sh` or a sibling script.
2. Use `wmctrl`/`xdotool` or Java accessibility only for local window discovery and typing.
3. Read the OTP inside that local helper via:

```bash
safe-op read "$TOTP_REF" --no-newline
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
- Whether `Mobile Authenticator app` exposes a code input after selecting it.
- Whether the TWS Java UI is easier to drive through `xdotool` key events or Java accessibility.

## Rollback Notes

No activation has occurred. If a future session activates Home Manager, record the current generation first:

```bash
home-manager generations
```

Build before switching:

```bash
nix build .#homeConfigurations."xing@desktop".activationPackage -L
```

If a post-activation smoke check fails, roll back to the recorded generation using the matching Home Manager generation path from `home-manager generations`.
