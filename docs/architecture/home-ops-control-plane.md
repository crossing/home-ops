# Home Operations Control Plane

Status: future direction; not currently implemented.

This repository is intended to grow from a collection of NixOS machines and
Home Manager profiles into a unified household operations control plane. The
repository should organize durable household outcomes while allowing their
implementation tools and providers to change independently.

This document records an architectural direction only. It does not describe
cloud resources that currently exist, and it does not authorize deployments or
changes to local systems.

## Capability-oriented organization

Future cloud automation and operational guidance should be grouped by
capability rather than by provider or automation technology. Initial
capabilities are expected to include:

- `mail`: custom-domain routing into Gmail and filtering of obvious spam.
- `remote-access`: zero-trust connectivity into the home network.
- `home`: documented setup and reconciliation for devices or services that
  cannot be fully automated.

The existing Snowfall layout remains the source of truth for Nix-managed
machines and user environments:

- `systems/` contains NixOS machine configurations.
- `homes/` contains Home Manager profiles.
- `modules/` contains reusable NixOS and Home Manager modules.

A possible future layout is:

```text
capabilities/
├── mail/
│   ├── infrastructure/
│   ├── reconciliation/
│   └── README.md
├── remote-access/
│   ├── infrastructure/
│   ├── reconciliation/
│   └── README.md
└── home/
    ├── procedures/
    ├── reconciliation/
    └── README.md

infrastructure/
├── modules/
└── environments/
    └── production/
```

Capability directories would compose resources around an operational outcome.
Reusable provider-level OpenTofu modules would live under `infrastructure/`
and must not encode household-specific policy. This separates stable intent
from replaceable implementations such as Cloudflare, Google, or AWS.

## Agent-driven reconciliation

Procedures for physical, browser-mediated, or otherwise unautomatable setup
should be structured for safe inspection and agent-guided reconciliation. Each
procedure should record:

- desired state;
- prerequisites and dependencies;
- how to inspect current state;
- safe reconciliation actions;
- steps requiring human approval or physical action;
- evidence that confirms success;
- rollback or recovery guidance; and
- the date and context of the last successful verification.

Agents should distinguish observation from mutation, present evidence of drift,
and stop at documented approval boundaries. Prose alone is not considered a
sufficient reconciliation interface when a procedure can instead provide
explicit checks and success criteria.

## OpenTofu state

OpenTofu state must remain outside Git and survive the loss or rebuild of every
managed home machine. The preferred future backend is a dedicated private AWS
S3 bucket with:

- bucket versioning for recovery from accidental replacement or deletion;
- server-side encryption using AWS KMS;
- S3 public access blocked;
- least-privilege IAM access limited to the required state paths; and
- OpenTofu native S3 locking enabled with `use_lockfile`.

Backend and provider credentials should be stored in 1Password and injected
into the OpenTofu process at runtime. Credentials, account identifiers, state
snapshots, backend configuration containing secrets, and saved plans must not
be committed.

State should be separated according to lifecycle and blast radius rather than
provider. The initial expected keys are conceptually:

```text
production/mail.tfstate
production/remote-access.tfstate
production/shared.tfstate
```

The exact bucket, region, key layout, encryption configuration, and IAM model
must be reassessed before implementation. Creating the backend should be a
separate bootstrap activity, independent of the resources whose state it
stores.

## Recovery expectations

Durability requires more than remote storage. The eventual operating procedure
should protect AWS account recovery material and MFA recovery codes outside the
managed machines, document how 1Password access is recovered, and periodically
test restoration of a previous state-object version. If OpenTofu client-side
state encryption is adopted later, its key must have an independent recovery
copy because loss of that key makes the state unreadable.

These controls and recovery tests are future requirements, not claims about the
repository's current infrastructure.
