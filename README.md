# Home Operations

This repository manages NixOS and Home Manager configurations using [Snowfall Lib](https://snowfall.org/), an opinionated framework for organizing Nix Flakes.

## Project Structure

Snowfall strictly enforces a directory structure to automatically discover and wire up Nix derivations. Below is how this project maps to the Snowfall standard:

- **`systems/`**: Contains NixOS machine configurations.
  - Structure: `systems/<architecture>-<os>/<hostname>/default.nix` (e.g. `systems/x86_64-linux/desktop`).
  - Represents the system-level configurations that you would typically apply via `nixos-rebuild`.

- **`homes/`**: Contains Home Manager configurations for users.
  - Structure: `homes/<architecture>-<os>/<username>@<hostname>/default.nix` (e.g. `homes/x86_64-linux/xing@desktop`).
  - Represents user command-line tools, GUI applications, dotfiles, and environments installed via `home-manager`.

- **`modules/`**: Shared Nix modules that can be imported to extend NixOS or Home Manager system options.
  - `modules/nixos/`: Modules exposed specifically to system configurations.
  - `modules/home/`: Modules exposed specifically to user (Home Manager) configurations.

- **`overlays/`**: Contains Nixpkgs overlays to patch, augment, or cherry-pick packages across the flake.
  - Each directory inside `overlays/` exports a specific overlay (e.g. `overlays/unstable` pulls tools like Antigravity and Docker from the `nixpkgs-unstable` channel).

- **`packages/`**: Custom, natively built packages maintained by this flake.
  - Snowfall will automatically discover and export them as `packages.<system>.<package-name>`.

- **`shells/`**: Development environment definitions (`devShells`).
  - Contains `.nix` files dictating what dependencies and shell hooks are provided when running `nix develop`.

- **`secrets/`**: Encrypted keys, passwords, and sensitive variables, designed to be managed and securely injected at deploy-time via tools like `sops-nix`.

## Making Changes

When adding new files or directories:
1. **You must stage them via Git** before attempting a build, otherwise Nix Flake evaluation will fail with a "path does not exist" error.
2. Run the automated check via the native workflow `.agents/workflows/verify-build.md` (or simply type `run /verify-build`) to safely compile the Home Manager profile.
