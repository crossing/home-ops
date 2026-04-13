# SYSTEMS: Knowledge Base

Generated: Automatically by /init-deep

Overview
Holds NixOS machine configurations (e.g. `systems/x86_64-linux/desktop`). Each host directory exposes a `default.nix` and optional `configuration/` subdirectory for modular pieces.

Where to look
- Host entry: `systems/<arch>-<os>/<hostname>/default.nix`
- Modular pieces: `systems/*/configuration/*.nix` (networking, users, hardware, etc.)

Conventions
- Keep machine-specific hardware and networking in `configuration/` and leave high-level options in the host `default.nix` for clarity.

QA: Use the `nix build` targets referenced in `.agents/workflows/verify-build.md` for the specific host to validate changes.
