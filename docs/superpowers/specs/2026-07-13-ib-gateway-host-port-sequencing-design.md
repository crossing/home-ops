# IB Gateway host-port sequencing design

## Problem

The bridge-network experiment isolated container namespaces, but it also
changed Gateway's client source address and did not produce a reliable second
profile authentication flow. The earlier host-network run showed a different
failure: `main-live` stopped listening after `pension-live` started, even
though their persistent data, runtime credentials, container names, client
IDs, and configured API ports were distinct.

Gateway starts on its mode-specific default port before IBC applies
`OverrideTwsApiPort`. Concurrent host-network startup or restart can therefore
make two instances contend transiently even when their steady-state ports
differ.

There is not enough paper evidence to disprove the same risk. Only an old
`main-paper` TWS configuration exists; there is no `pension-paper` Gateway
runtime or dual-paper journal history.

## Design

Restore Podman host networking and keep every configured API endpoint away
from IBKR's defaults:

- `main-live`: 4005
- `main-paper`: 4006
- `pension-live`: 4003
- `pension-paper`: 4004

The live Gateway coordinator processes profiles in order. For each profile it
starts the existing reauthentication helper when needed, then polls a
constrained `ibkr-local connect --profile PROFILE` handshake. It does not
start the next profile until the current profile is both service-active and
API-ready. A bounded timeout fails closed and leaves later profiles untouched.

Set different authenticated IBC restart times for the enabled live profiles:
`main-live` at 11:35 PM and `pension-live` at 11:55 PM. This reduces the chance
that both applications transiently use port 4001 during an automatic restart.

The existing per-profile data directories, credentials, client IDs, named
containers, read-only defaults, and order-mutation guard remain unchanged.

## Verification

1. A wrapper regression test requires host networking and rejects the bridge
   publication implementation.
2. A profile regression test requires all four ports to be unique and rejects
   4001 and 4002.
3. Coordinator tests prove that the second helper waits for the first API
   handshake, and that failure or timeout prevents the second start.
4. Build `ibgateway`, `ibkr-local`, and the desktop Home Manager generation.
5. Activate the verified units, authenticate `main-live` first, require an API
   handshake on 4005, then authenticate `pension-live` and require both 4005
   and 4003 handshakes to remain healthy.

## Safety boundaries

All secret reads remain local behind `safe-op`. Never print credentials, OTPs,
account identifiers, generated IBC configuration, financial rows, or scoped
1Password session values. Back up mutable unit links before replacement and
retain the prior generation as the rollback path.
