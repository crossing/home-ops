# IB Gateway IBC autorestart parser design

## Problem

The verified `main-live` Gateway survived its initial authenticated launch but
failed at the configured weekday IBC restart. When Gateway exited normally,
IBC re-entered `find_auto_restart`; its `xargs dirname` and `cut` pipeline
returned command-not-found errors, so the service exited with status 127 and
port 4001 closed.

An image-level test disproved the original missing-package hypothesis: the
unchanged Dockerfile builds an image in which both commands resolve and run.
The fix therefore belongs at the failing post-JVM parser boundary, not in the
image dependency list.

## Design

Keep the existing Gateway/IBC architecture and container dependencies
unchanged. Patch the packaged IBC 3.24.1 `find_auto_restart` function to derive
the one-level autorestart directory using Bash parameter expansion rather than
the `xargs dirname` and `cut` pipeline.

Add a narrow executable regression test that extracts the real packaged
function, makes only `find` available through a shell function, and verifies
that a `Jts/session/autorestart` file produces `-Drestart=session`. The test
must fail against the unpatched package and pass against the patched package.

## Verification

1. Observe the regression test fail against the unpatched IBC script with the
   same `xargs`/`cut` errors as the live scheduled restart.
2. Apply the Bash-only parser patch and observe the test pass.
3. Rebuild the `ibgateway`, `ibkr-local`, and Home Manager activation outputs.
4. Reauthenticate `main-live`, exercise a controlled service stop/start, and
   verify clean container/runtime-directory cleanup.
5. Resume `ibkr-gateway-ensure-live`, complete pension 2FA if the device offers
   it, and verify ports, stable invocation IDs, idempotence, and sanitized API
   row counts.

## Safety boundaries

All credential reads remain behind `safe-op`. Do not print credentials, OTPs,
account identifiers, generated IBC configuration, financial rows, or scoped
1Password session values. The constrained `ibkr-local` wrapper remains the
only API client used for order previews, and submit/cancel/modify remain
unavailable.
