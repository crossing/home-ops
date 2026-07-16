# IBKR Gateway 2FA Diagnostics Design

## Goal

Keep `ibkr-gateway-ensure-live` as the ordered bootstrap entry point while making a missing IB Key push immediately diagnosable and documenting the proven challenge/response fallback in the investment operations skill.

## Coordinator behavior

The coordinator continues to start and verify profiles in order. When a profile is active but its API is not yet ready, it prints concise, secret-free guidance immediately instead of waiting silently for the full readiness timeout. The guidance identifies the service and journal commands, explains that `Notification sent` does not prove phone delivery, directs the operator to the Gateway's Challenge/Response path, and warns against repeated restarts while a challenge is pending.

Use the primary `ibkr` command when available and retain `ibkr-local` as a compatibility fallback.

## Investment skill

The skill remains coordinator-first. Its fallback section distinguishes pre-authentication service/configuration failures from a stable Second Factor Authentication dialog, explains how to attach to the headless X display without exposing credentials, requires capturing and visually inspecting the dialog before every click, and records the IBKR Mobile Services -> Authenticate challenge/response flow.

Do not hard-code screen coordinates. Gateway UI layout can change. The skill reminds the operator to review the installed coordinator output and current Gateway dialog after IB Gateway or IBC upgrades.

## Safety and verification

- Never print credentials, generated IBC configuration, or 1Password session state.
- Do not restart a profile repeatedly while a challenge is pending.
- Preserve ordered startup: `main-live` must be API-ready before `pension-live` starts.
- Add a focused coordinator regression test that fails before the new guidance exists.
- Validate the updated skill with the skill validator and verify both live profiles remain reachable.
