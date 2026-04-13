# PROJECT KNOWLEDGE BASE

Generated: Automatically by /init-deep

Overview
This repository is a Nix Flake that manages NixOS system and Home Manager configurations using the Snowfall framework. Primary concerns: configuration files under `systems/`, per-user homes under `homes/`, shared modules in `modules/`, and custom packages in `packages/`.

Structure (non-obvious)
```
./
├── flake.nix            # flake entry
├── systems/             # NixOS machine configurations (per-host)
├── homes/               # Home Manager profiles (per-user@host)
├── modules/             # Shared Nix modules
├── packages/            # Custom nix packages
└── overlays/            # Nixpkgs overlays
```

Where to look
- System config: `systems/<arch>-<os>/<hostname>/default.nix`
- Home config: `homes/<arch>-<os>/<user>@<host>/default.nix`
- Build verification workflow: `.agents/workflows/verify-build.md`

Conventions (project-specific)
- This project uses Snowfall conventions for automatic discovery — add new packages/modules following the existing directory patterns.
- Shared Home Manager modules belong under `modules/home/<module-name>/default.nix` and are auto-discovered as home modules; do not add new shared home modules as flat `modules/home/<name>.nix` files.
- Per-user home modules live alongside the profile under `homes/<arch>-<os>/<user>@<host>/...` and are imported from that profile only when they are user-specific.
- When moving or renaming a module path, stage the new path with Git before building so the flake evaluates against the tracked tree.

Commands
```
# Evaluate/build individual targets (example)
nix build .#homeConfigurations."xing@desktop".activationPackage -L
```

Notes
- Always git-add new/renamed files before running Nix build (flake evaluation reads repo state).
- Snowfall root layout expected by this repo: `flake.nix`, `lib/`, `packages/`, `modules/`, `overlays/`, `systems/`, `homes/`.
- Snowfall module discovery in this repo follows the directory form:
  - `modules/nixos/<name>/default.nix` -> NixOS module
  - `modules/darwin/<name>/default.nix` -> Darwin module
  - `modules/home/<name>/default.nix` -> Home Manager module
- Prefer `default.nix` inside a module directory for future conversions; that keeps the path aligned with Snowfall docs and avoids manual import churn.

CODE MAP
| Symbol | Type | Location | Notes |
|---|---|---|---|
| flake outputs | flake | flake.nix | Uses snowfall-lib.mkFlake; maps self.nixosConfigurations into deploy.nodes
| home profiles | homeConfigurations | homes/*/*/default.nix | User@host profiles discovered by Snowfall (e.g. homes/x86_64-linux/xing@desktop/default.nix)
| system configs | nixosConfigurations | systems/*/*/default.nix | Host configs and modular configuration/ subdirs (networking, hardware, users)
| custom packages | packages | packages/*/default.nix | Exported as packages.<system>.<name> by the flake
| overlays | overlays | overlays/*/default.nix | Nixpkgs overlays applied via flake
| verify workflow | docs | .agents/workflows/verify-build.md | Exact nix build targets and staging instructions
