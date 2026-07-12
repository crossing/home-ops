# Agent setup

This directory is the durable recovery ledger for the mutable agent capability
layer on Xing's NixOS machines.

Home Manager owns executables, libraries, environment integration, and other
non-FHS runtime requirements. Skill content is intentionally mutable and lives
under the discovery roots used by each agent, principally
`~/.agents/skills`. Plugins remain owned by Codex's plugin installer and cache.

Start with [bootstrap.md](bootstrap.md) when rebuilding a machine or loading
this setup into a fresh agent. Use [inventory.md](inventory.md) for provenance
and [nix-runtime.md](nix-runtime.md) before installing any new executable
dependency.

The ledger stores metadata, not a mirror of every external skill. It must never
contain secret values, cookies, authentication state, browser profiles, or
credential exports.

## Ownership boundary

| Concern | Owner |
| --- | --- |
| Agent executables and native libraries | Nix/Home Manager |
| Mutable personal skills | Native installer or local Git checkout |
| Codex plugin skills | Codex plugin installer/cache |
| Provenance, recovery and decisions | This directory |
| Credentials and authentication state | Existing secret stores; never this ledger |

## Maintenance

The scheduled weekly review runs on Sunday at 10:00 Europe/London. It may
maintain mutable skills, but runtime package changes are proposals for review.
Material repository changes are published from a dated `codex/` branch as a
draft pull request.
