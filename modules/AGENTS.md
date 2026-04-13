# MODULES: Knowledge Base

Generated: Automatically by /init-deep

Overview
Shared Nix modules used by systems and homes. Typical layout: `modules/nixos/` for system modules and `modules/home/` for Home Manager modules.

Where to look
- System modules: `modules/nixos/`
- Home modules: `modules/home/`

Conventions
- Modules should be small, focused, and well-documented. Expose options that are composable by host and home configurations.

Notes
- Avoid duplicating logic between `modules/` and `homes/` — prefer importing modules from host/home profiles.
