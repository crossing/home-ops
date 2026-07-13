# IB Gateway IBC runtime tools design

## Problem

The verified `main-live` Gateway survived its initial authenticated launch but
failed at the configured weekday IBC restart. IBC's `ibcstart.sh` invoked
`xargs` and `cut`; neither executable exists in the current Ubuntu image, so
the service exited with status 127 and port 4001 closed.

## Design

Keep the existing Gateway/IBC architecture unchanged. Add the Ubuntu packages
that provide IBC's missing runtime commands (`findutils` for `xargs` and
`coreutils` for `cut`) to `packages/ibgateway/Dockerfile`.

Add a narrow executable regression test that builds the Dockerfile image and
checks the required commands inside that image. The test must fail against the
current Dockerfile, pass after the dependency change, and emit only command
availability status.

## Verification

1. Observe the regression test fail because `xargs` and `cut` are absent.
2. Add the two image dependencies and observe the test pass.
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
