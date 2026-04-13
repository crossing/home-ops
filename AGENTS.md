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

Commands
```
# Evaluate/build individual targets (example)
nix build .#homeConfigurations."xing@desktop".activationPackage -L
```

Notes
- Always git-add new/renamed files before running Nix build (flake evaluation reads repo state).

CODE MAP
| Symbol | Type | Location | Notes |
|---|---|---|---|
| flake outputs | flake | flake.nix | Uses snowfall-lib.mkFlake; maps self.nixosConfigurations into deploy.nodes
| home profiles | homeConfigurations | homes/*/*/default.nix | User@host profiles discovered by Snowfall (e.g. homes/x86_64-linux/xing@desktop/default.nix)
| system configs | nixosConfigurations | systems/*/*/default.nix | Host configs and modular configuration/ subdirs (networking, hardware, users)
| custom packages | packages | packages/*/default.nix | Exported as packages.<system>.<name> by the flake
| overlays | overlays | overlays/*/default.nix | Nixpkgs overlays applied via flake
| verify workflow | docs | .agents/workflows/verify-build.md | Exact nix build targets and staging instructions
