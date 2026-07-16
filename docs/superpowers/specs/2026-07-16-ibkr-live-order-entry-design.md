# Guarded IBKR Live Order Entry Design

## Goal

Allow the local IBKR command to place and cancel live orders without exposing
the unrestricted upstream CLI. Preserve preview-first operation, require an
explicit profile and account for every live mutation, and prevent accidental
duplicate submission after retries or ambiguous broker responses.

The primary installed command becomes `ibkr`. The existing `ibkr-local` name
remains as a compatibility alias with identical behavior and output.

## Current boundary

Both configured live Gateways already use non-read-only logins and permit API
writes because IBKR requires write access for what-if previews. The pinned
upstream `ibkr-cli` 0.7.1 supports real submission, cancellation, and
modification. The local wrapper currently exposes preview only and rejects all
mutation tokens.

This change opens a narrow mutation path in the wrapper. It does not expose the
upstream binary, relax Gateway network trust, or give callers a generic
passthrough.

## Command and packaging boundary

`packages/ibkr-local` continues to be the user-facing package. It installs:

- `bin/ibkr`, the guarded wrapper and primary command.
- `bin/ibkr-local`, a compatibility symlink to the same wrapper.
- The existing Gateway launcher commands.

The upstream `${ibkr-cli}/bin/ibkr` is referenced by an absolute Nix store path
inside the wrapper. It is not added to the wrapper's runtime `PATH` or linked
into the package output. This prevents the new `ibkr` name from recursing into
itself and prevents callers from reaching unrestricted upstream mutation
commands through the installed package.

Help text and new documentation use `ibkr`. Compatibility invocations through
`ibkr-local` produce no warning or extra output so existing JSON consumers do
not break.

The existing side-effect-free command remains available:

```text
ibkr order-preview buy|sell SYMBOL QUANTITY [options]
```

The initial live-order surface adds:

```text
ibkr order-prepare buy|sell SYMBOL QUANTITY \
  --profile PROFILE --account ACCOUNT --type LMT --limit PRICE

ibkr order-submit TICKET_ID --confirm TICKET_ID

ibkr order-cancel ORDER_ID \
  --profile PROFILE --account ACCOUNT --confirm ORDER_ID
```

`order-prepare` and `order-submit` are deliberately separate processes. Submit
accepts no order-defining flags; it reconstructs the upstream command only from
the immutable prepared ticket.

## Declarative policy

Each `programs.ibkrLocal.profiles.<name>` gains an `orderEntry` policy with
fail-closed defaults:

```nix
orderEntry = {
  enable = false;
  ticketTtlSeconds = 120;
  allowedOrderTypes = [ "LMT" ];
  allowOutsideRth = false;
};
```

The generated `profiles.json` carries this non-secret policy. The first runtime
proof enables it for a paper profile. After the paper lifecycle passes, the
desktop configuration enables the same policy for `main-live` and
`pension-live`.

Live prepare, submit, and cancel always require explicit `--profile` and
`--account`; neither the default profile nor account groups may select a live
mutation target. Upstream must report the requested account as the selected
managed account during preview.

## Initial order scope

The first release supports:

- Stock buy and sell limit orders.
- `DAY` time in force.
- Regular trading hours only.
- Cancellation of an explicitly identified open order.

It rejects market, stop, trailing, bracket, outside-hours, and non-`DAY`
orders. Order modification remains blocked. These capabilities can be designed
as later milestones after the ticket lifecycle has been proven in live use.

## Preparation and ticket contents

`order-prepare` validates local policy, calls the upstream what-if operation,
and creates a private ticket only after a successful preview. The ticket uses a
random identifier and canonical JSON containing:

- Schema version, ticket identifier, creation time, and expiry time.
- Local and upstream profile names and the profile's trading mode.
- Explicit account, action, symbol, quantity, exchange, currency, order type,
  limit price, time in force, and outside-hours value.
- IBKR-qualified contract identifiers and IBKR's selected account.
- The preview status, commission range, margin changes, warning text, and raw
  broker error codes.
- A checksum over the canonical order payload to detect corruption or editing.

Prepared tickets live under
`$XDG_RUNTIME_DIR/ibkr-local/order-tickets/prepared/`. A sibling `claimed/`
directory provides the same-filesystem atomic submission claim. Both
directories are mode `0700` and ticket files are mode `0600`. A ticket expires
after 120 seconds by default.
Ticket identifiers and checksums protect against accidental misuse, not against
the local account owner, who already controls the CLI and its configuration.

## Submission state machine

Submission uses this state machine:

```text
prepared -> submitting -> submitted
                       -> attempted-unknown
                       -> rejected
```

Before broker contact, `order-submit` verifies the ticket schema, checksum,
expiry, exact confirmation, current profile policy, live mode, explicit account,
and allowed order type. It then atomically renames the ticket from `prepared`
to `claimed` under the same runtime parent. Only the process that wins this
transition may create the durable audit record and invoke upstream `--submit`;
concurrent and repeated attempts fail locally. The claimed ticket is copied to
durable audit state before broker contact, avoiding any assumption that runtime
and state directories share a filesystem.

Every broker-contacting submission consumes its ticket. A nonzero exit,
timeout, signal, malformed response, or lost connection becomes
`attempted-unknown` unless the response proves a broker rejection. The wrapper
never restores the ticket or retries automatically. It instructs the caller to
inspect open orders, completed orders, and executions before preparing another
order.

An upstream success response records the broker order identifiers and observed
status as `submitted`. Success means IBKR accepted the order request, not that
the order filled.

## Cancellation

Cancellation cannot use a what-if preview, so it has a direct but constrained
command. It requires an explicit profile, account, order ID, and matching typed
confirmation. The wrapper verifies that order entry is enabled and then calls
the pinned upstream cancellation command.

Each cancellation invocation gets its own durable attempt record. An uncertain
result is never retried automatically; the caller must refresh open/completed
orders first. Cancellation remains fast and does not require creating a prepare
ticket, because preventing an unwanted fill is more important than matching the
submission workflow.

## Audit data

Durable records live under `$XDG_STATE_HOME/ibkr-local/orders/` in a `0700`
directory with `0600` JSON files. Records include the canonical order, ticket
state transitions, timestamps, sanitized upstream response, and broker order
identifiers when available.

Audit data contains sensitive local financial metadata, including the account
and order details, but never credentials, 1Password state, environment dumps,
or Gateway configuration. Normal error output remains concise and does not dump
portfolio rows.

## Failure behavior

- Disabled or missing policy fails before preview or broker mutation.
- Missing explicit profile/account fails even if defaults are configured.
- Preview failure creates no ticket.
- Expired, malformed, edited, consumed, or confirmation-mismatched tickets fail
  before broker contact.
- An account mismatch between the request and IBKR preview fails preparation.
- Broker warnings remain visible in the ticket and submit result.
- Submission ambiguity consumes the ticket and requires reconciliation.
- Cancellation ambiguity requires reconciliation before another cancellation.
- The wrapper never submits an offsetting order automatically.

## Verification and rollout

Add a focused shell test with a fake upstream executable, fake profiles, and
isolated runtime/state directories. It must prove:

- The policy defaults to disabled.
- Explicit profile and account are mandatory.
- Unsupported order types and flags are rejected.
- Preview failure creates no ticket.
- Valid preview creates a correctly protected, canonical ticket.
- Expiry, checksum mismatch, malformed content, and confirmation mismatch fail
  before broker contact.
- Two concurrent submissions of one ticket invoke upstream `--submit` at most
  once.
- A timeout or malformed response consumes the ticket as `attempted-unknown`.
- Cancellation requires all identifiers and records ambiguous outcomes.
- `ibkr` and `ibkr-local` have identical behavior.
- The installed `ibkr` is the wrapper and the raw upstream CLI is absent from
  the package output.

Then run shell syntax checks, formatting checks, the existing IBKR policy tests,
the focused package build, and the full `xing@desktop` Home Manager activation
package build. All repository changes must be staged before Nix evaluates the
flake.

Before any activation, record the current Home Manager generation and its
rollback command. After static/build verification, activate the paper-only
policy and place then cancel a deliberately non-marketable paper limit order.
Only after that lifecycle passes should a second configuration update enable
`main-live` and `pension-live`.

Live acceptance stops after generating and validating a user-chosen preview
ticket. Submitting a live acceptance ticket requires a separate explicit user
instruction. A filled live order is never automatically reversed.

## Non-goals

- General access to the upstream CLI.
- Autonomous or unattended trading.
- Automatic retries, scheduled orders, or strategy execution.
- Market, bracket, stop, trailing, outside-hours, or modification support.
- Changing Gateway authentication, network trust, or service lifecycle.
- Activating Home Manager or touching authenticated live Gateway state during
  automated verification.

## Acceptance criteria

The change is ready when the guarded `ibkr` command can prepare a successful
IBKR preview, issue a short-lived immutable ticket, submit that ticket at most
once on an enabled profile, and cancel an explicitly identified order; all
fail-closed tests and Nix builds pass; `ibkr-local` remains compatible; and no
unrestricted upstream command is exposed.
