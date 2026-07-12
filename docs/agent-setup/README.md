# Agent setup

This directory is the durable recovery ledger for the mutable agent capability
layer on Xing's NixOS machines. It applies to every agent installed by the
active Home Manager profile, not only Codex.

Home Manager owns executables, libraries, environment integration, and other
non-FHS runtime requirements. Skill content is intentionally mutable and lives
under the shared and agent-native discovery roots documented in
[`reviews.md`](reviews.md). Plugins remain owned by their agent's installer.

Start with [bootstrap.md](bootstrap.md) when rebuilding a machine or loading
this setup into a fresh agent. Use [inventory.md](inventory.md) for provenance,
[nix-runtime.md](nix-runtime.md) for installed agents and dependencies, and
[reviews.md](reviews.md) to create or run the weekly review.

The ledger stores metadata, not a mirror of every external skill. It must never
contain secret values, cookies, authentication state, browser profiles, or
credential exports.

## Ownership boundary

| Concern | Owner |
| --- | --- |
| Agent executables and native libraries | Nix/Home Manager |
| Mutable personal skills | Native installer or local Git checkout |
| Agent-native bundled/plugin skills | The corresponding agent installer/cache |
| Provenance, recovery and decisions | This directory |
| Credentials and authentication state | Existing secret stores; never this ledger |

## Maintenance

The scheduled weekly review runs on Sunday at 10:00 Europe/London. It may
maintain mutable skills, but runtime package changes are proposals for review.
Material repository changes are published from a dated `codex/` branch as a
draft pull request. Bootstrap must create or verify this review after activating
Home Manager, with exactly one installed agent acting as the scheduler.
