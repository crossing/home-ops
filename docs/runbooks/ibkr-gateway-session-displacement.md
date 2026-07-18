# IBKR Gateway same-username session priority

Every managed IBKR Gateway renders IBC's
`ExistingSessionDetectedAction=primary` policy. Starting Gateway with a
username that is already active will request that the competing TWS, IB
Gateway, IBKR Mobile, or Client Portal brokerage session using that username be
terminated so the managed Gateway can proceed.

This is deliberately disruptive. Do not start or reauthenticate a managed
Gateway while relying on another same-username brokerage session.

IBC 3.24.1 documents the exact boundary: an established `primary` session
cannot be overridden by any new session, and an existing `manual` session
requires user handling. The `primary` policy also reconnects the managed
session if another session is manually allowed to end it. See the
[upstream IBC 3.24.1 configuration reference](https://raw.githubusercontent.com/IbcAlpha/IBC/3.24.1/resources/config.ini).

The session-priority policy does not relax the other Gateway controls: API trust
remains localhost-only, unknown incoming API connections are rejected, second
factor relogin is not retried without bound, and ephemeral credentials are
mode-0600 and removed by the owning start/reauth lifecycle.
