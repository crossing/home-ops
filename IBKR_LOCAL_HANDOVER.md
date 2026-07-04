# IBKR Local Integration Handover

Date: 2026-07-04
Branch: `feature/ibkr-local-integration`

## Current State

This branch contains the local-only Interactive Brokers integration. It implements the local `ibkr-cli` plus TWS/IBC path; no MCP or hosted connector integration is used.

The important files are:

- `packages/ibkr-local/default.nix`
- `packages/ibkr-local/ibkr-local.sh`
- `packages/ibkr-local/test-ibc-login.sh`
- `modules/home/ibkr-local/default.nix`
- `homes/x86_64-linux/xing@desktop/default.nix`
- `homes/x86_64-linux/xing@desktop/ibkr.nix`
- `packages/tws/Dockerfile`
- `packages/tws/default.nix`
- `packages/tws/wrapper.sh`

The live login test now reaches the expected second-factor prompt for the `crossing2p` IBKR item.

## Implemented

- Added `packages/ibkr-local`, exposing `ibkr-local` and `tws`.
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
  - separate display mode from app mode, so `--xvfb --ibc` works
  - explicit `--visible`, `--x11`, `--xvfb`, and `--ibc` support
  - `TWS_DIR`, `CONFIG_DIR`, and `TWS_LOG_DIR` support
  - in-container JTS path is consistently `/home/tws/Jts`
  - `xvfb-run` added to the TWS package runtime inputs
- Added `packages/ibkr-local/test-ibc-login.sh`:
  - defaults to `main-live`
  - validates the 1Password item username with `safe-op read`
  - renders the IBC config through `safe-op read` secret refs
  - verifies generated config path, mode `0600`, and `TradingMode`
  - refuses paper mode unless `--allow-paper` is passed
  - sanitizes username, password, and JxBrowser key from logs
  - only treats 2FA/logged-in evidence as authentication success

## Safety Constraints

- v1 is read-only plus what-if order preview only.
- `ibkr-local order-preview` always appends upstream `--preview`.
- `--submit`, `submit`, `cancel`, and `modify` are blocked by the wrapper.
- `order-preview --account ACCOUNT` is forwarded to upstream `ibkr buy/sell --account ACCOUNT`.
- `ibc-config` refuses to read secrets unless `safe-op` is available.
- `ibc-config` reads username/password through `safe-op read op://... --no-newline`; it does not call raw `op`.
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

Treat the OTP as a secret. For the next step, prefer:

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
packages/ibkr-local/test-ibc-login.sh --render-only --item-id 3drrbjgoksyc3tuu4yxyvshjvq
```

Latest successful package path:

```text
/nix/store/cyn35y9n04473njw8kizpv6blipi3rpy-ibkr-local
```

Full live launch command used:

```bash
packages/ibkr-local/test-ibc-login.sh --duration 300 --item-id 3drrbjgoksyc3tuu4yxyvshjvq
```

Observed evidence:

- TWS installed under `~/.local/share/ibkr/main-live/tws`.
- IBC started with `TradingMode=live`.
- Local launcher log reached authentication and listed second-factor devices.
- X11 window enumeration showed `Second Factor Authentication`.
- Window screenshot showed `Select second factor device` with `IB Key` and `Mobile Authenticator app`.
- The managed test runner was stopped after recording the 2FA prompt.
- No TWS/podman test processes remained afterward.
- No `ibkr-ibc*` or `ibkr-ibc-test*` temp credential directories remained afterward.

## Known Blocker

Full non-activation Home Manager build was attempted earlier:

```bash
nix build --no-link .#homeConfigurations."xing@desktop".activationPackage -L
```

It failed on an unrelated existing fixed-output hash mismatch for `Codex.dmg`:

```text
specified: sha256-gPAmEhtiPTtfMXI5qiAmBdkMD+DkWewnyFm6I2kjzbs=
got:       sha256-deZwuJSNJirI6jrY9hFJ49AkCgTmygtrwkmsVP2D1D4=
```

This is in the existing Codex desktop closure, not the IBKR local integration. The activation derivation path previously evaluated successfully.

## Next Step: Fill 2FA From 1Password

Goal: when TWS reaches the `Second Factor Authentication` window, read the current OTP locally through `safe-op`, select the correct second-factor path if needed, and fill/submit the code without exposing it in logs or chat.

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
