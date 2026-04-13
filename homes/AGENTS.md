# HOMES: Knowledge Base

Generated: Automatically by /init-deep

Overview
Contains Home Manager profiles for users (e.g. `homes/x86_64-linux/xing@desktop`). Each folder under `homes/` represents a user@host pairing and exposes a `default.nix` that Snowfall will discover.

Where to look
- User profile: `homes/<arch>/<user>@<host>/default.nix`
- Per-user modules: `homes/*/*/` (see `ai/`, `developer/`, `apps/` subdirs)

Conventions
- Per-user directories contain modular `.nix` files (apps, developer, ssh, desktop). Use the same structure when adding new user profiles.

QA: To verify changes to a home, run the exact `nix build` target shown in `.agents/workflows/verify-build.md` for the affected home.

CODE MAP
| Symbol | Type | Location | Notes |
|---|---|---|---|
| example home | home profile | homes/x86_64-linux/xing@desktop/default.nix | Contains user-level modules (ai/, developer/, apps/)
| per-user modules | modules | homes/*/*/* | App, developer, and ssh modules live alongside default.nix
