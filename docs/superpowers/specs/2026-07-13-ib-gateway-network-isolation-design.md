# IB Gateway network isolation design

## Problem

The two live Gateway profiles already use distinct installation, Jts, log,
runtime-credential, container, credential-item, API-port, and client-ID state.
They still share the host network namespace through `--net=host`.

The live failure follows that remaining shared boundary. `main-live` listened
on 4001 until `pension-live` started. Each new pension session initially
reported Gateway's default API port 4001 before IBC changed it to 4003; after
pension began listening on 4003, main's 4001 listener was gone even though its
service and Java processes remained active.

## Design

Run every Gateway container in its own Podman bridge network namespace. Pass
the configured profile API port into the wrapper as `IBKR_API_PORT`, validate
that it is an integer from 1 through 65535, and publish only
`127.0.0.1:PORT:PORT/tcp`.

This preserves local CLI access while allowing both containers to use their
internal default 4001 during startup without contending in the host namespace.
The existing per-profile data mounts, deterministic container names, Xvfb
layout, credentials, and cleanup behavior remain unchanged.

## Verification

1. Add a shell regression test that fails while the wrapper uses host
   networking and lacks the loopback publish rule.
2. Generate the exact bridge/publish arguments for ports 4001 and 4003 and
   reject missing or invalid IBC ports.
3. Build `ibgateway`, `ibkr-local`, and the desktop Home Manager generation.
4. Reauthenticate both profiles, confirm each container has a distinct network
   namespace, and require host listeners only on 127.0.0.1:4001 and
   127.0.0.1:4003.
5. Require both constrained API handshakes, stable coordinator invocation IDs,
   credential mode 0600, and no 1Password session variables in either service.

## Safety boundaries

All secret reads remain behind `safe-op`. Do not print credentials, OTPs,
account identifiers, generated IBC configuration, or financial rows. Preserve
the fail-closed order surface and the existing reversible unit-link backup.
