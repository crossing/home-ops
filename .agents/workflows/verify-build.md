---
description: Run Nix build to verify flake correctness after modifying configuration files.
---

// turbo

1. Stage all changes so Nix can read them.
```bash
git add -A
```

2. Evaluate and build the configuration corresponding to the modified files.
Based on the files you modified (or an explicit user request), determine the correct Nix build command. Example targets for `snowfall-lib`:
- Changes in `homes/x86_64-linux/xing@desktop/` -> Build `.#homeConfigurations."xing@desktop".activationPackage`
- Changes in `systems/x86_64-linux/desktop/` -> Build `.#nixosConfigurations.desktop.config.system.build.toplevel`
- Changes in `systems/x86_64-linux/gk/` -> Build `.#nixosConfigurations.gk.config.system.build.toplevel`

```bash
# Propose the specific `nix build` command that builds only the affected configurations.
# Example: nix build .#homeConfigurations."xing@desktop".activationPackage -L
```
