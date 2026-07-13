# Dual Live IB Gateway Design

## Goal

Run the existing main live IB Gateway instance and a new pension live instance through the current modular Home Manager configuration, with one idempotent command that ensures both are active without restarting a healthy session.

## Configuration

Enable the existing `pension-live` profile alongside `main-live`. Keep its established live profile values: API port 4003, client ID 22, and pension account grouping. Resolve the corresponding 1Password item by the non-secret username metadata `crossing2pension`, then configure username and password references by stable vault and item IDs.

Both profiles use the existing headless Gateway policy:

- Xvfb display mode.
- API write access enabled only because IBKR requires it for constrained what-if previews.
- Live login rather than read-only login.
- Manual `IB Key` second factor.
- Deterministic, per-profile service and container names.

No credentials, scoped 1Password sessions, or generated IBC configuration enter the aggregate command.

## Aggregate command

The Home Manager module generates `ibkr-gateway-ensure-live` from an explicit configured list of profiles. The desktop profile sets that list to `main-live` and `pension-live`.

For each configured profile, in order, the command checks its generated systemd user service:

1. If the service is active, report it as already active and leave it completely untouched.
2. If it is inactive, invoke that profile's existing `ibkr-gateway-reauth-PROFILE` helper once.
3. Confirm the service became active before moving to the next profile.
4. Record a failure and continue to the remaining profile rather than abandoning the whole pass.

The command prints a concise, credential-free per-profile result. It exits zero only when every configured service is active at the end. Repeated invocations against two healthy services perform no reauthentication, restart, or container mutation.

## Module boundaries

The existing per-profile generator remains responsible for credentials, ephemeral IBC configuration, service startup, cleanup, and second-factor behavior. The new aggregate generator only coordinates those generated helpers and systemd state checks.

The aggregate helper belongs in `modules/home/ibkr-local/default.nix`, beside the existing generated service and reauthentication helpers. Profile selection and pension credentials remain in `homes/x86_64-linux/xing@desktop/ibkr.nix`. The constrained broker commands in `packages/ibkr-local` do not gain systemd orchestration behavior.

## Failure handling

- An active service is never restarted merely because another profile is inactive or fails.
- A failed profile does not prevent the command from checking or starting the other profile.
- Missing profile configuration or a missing generated reauthentication helper fails closed during evaluation or command execution with the profile name, never credential details.
- The aggregate command returns nonzero when any configured service remains inactive.
- Each per-profile nonblocking reauthentication lock continues to prevent overlapping starts.

## Verification

Add a focused shell-level test for the aggregate command using controlled `systemctl` and reauthentication-helper doubles. Prove these behaviors before implementation:

- Two active services cause zero helper invocations.
- One inactive service invokes exactly its own helper once and does not touch the active service.
- Two inactive services invoke both helpers sequentially.
- A failed helper does not prevent the second profile from being checked, and the aggregate result is nonzero.

Then verify generated Home Manager configuration for both profiles, shell syntax, both package builds, the full Home Manager activation package, `git diff --check`, and the existing fail-closed `--submit` behavior. Do not activate a new Home Manager generation or disturb the currently authenticated `main-live` service until static and build checks pass.
