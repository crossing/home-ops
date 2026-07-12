# Nix runtime boundary

Home Manager owns the stable runtime needed by agents and mutable skills.

| Capability | Declarative owner |
| --- | --- |
| Codex CLI and Desktop | `modules/home/personal/ai/codex.nix` |
| Hermes Agent and Desktop | `modules/home/personal/ai/hermes.nix` |
| Antigravity, its CLI, GWS and Google Cloud SDK | `modules/home/personal/ai/google.nix` |
| Agent Browser CLI | `modules/home/personal/ai/default.nix` |
| RTK | `modules/home/personal/ai/default.nix` |
| Node.js, ripgrep and jq | `modules/home/personal/home.nix` |
| `safe-op` | local `safe-cli` flake input via the personal home module |
| Git, Git LFS and libsecret integration | `modules/home/personal/developer/git.nix` |

The `safe-cli` flake input is fetched directly from
`github:crossing/safe-cli` and pinned by `flake.lock`; no local checkout is
required.

## Dependency policy

For a skill requiring a new executable, use this order:

1. Existing Home Manager/Nixpkgs package.
2. A repository-specific `nix develop` environment.
3. A focused Nix wrapper or derivation.
4. `nix-ld` as a documented compatibility exception.
5. An FHS environment only when packaging the tool is not economical.

Do not use global npm/pip installs, hard-coded `/bin/bash`, `/usr/bin/python`,
or `/usr/local/bin`, or unmanaged dynamically linked Linux binaries. Ambient
Node.js does not replace wrapped runtimes embedded in packages such as Hermes.

Weekly maintenance may identify a runtime gap, but it must report the proposed
Nix change in its draft PR rather than modifying runtime packages automatically.
