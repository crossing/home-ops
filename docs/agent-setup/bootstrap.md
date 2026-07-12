# Bootstrap agent capabilities

This procedure is designed to be handed to a fresh Codex agent.

1. Target `x86_64-linux`, user `xing`, with the repository cloned from
   `https://github.com/crossing/home-ops.git`. Read this directory and the
   repository `AGENTS.md`. Do not inspect or copy credentials, cookies,
   authentication state, or browser profiles.
2. Clone `https://github.com/crossing/safe-cli.git` at
   `3468c1765b767f7e360ae6a702091aea18c27bc1` into
   `~/works/home/safe-cli`. The flake intentionally consumes that local path;
   verify its locked NAR hash before accepting different content.
3. Build the Home Manager target before changing live skills:
   `nix build '.#homeConfigurations."xing@desktop".activationPackage' -L`.
4. Activate it with `./result/activate`, then confirm the Nix-owned runtime
   described in `nix-runtime.md`. Do not use
   global npm/pip installs or downloaded dynamically linked binaries as a
   substitute for missing Nix packages.
5. Inventory `~/.agents/skills`, `~/.codex/skills`, enabled Codex skill config,
   and concrete plugin cache versions. Compare names, locations, source
   revisions, and `sha256sum SKILL.md` with `inventory.md`. The six installed
   GWS skills are intentionally disabled for Codex; do not treat their absence
   from its live prompt as a loader failure.
6. Reinstall only missing mutable skills whose provenance is unambiguous.
   Preserve the installed skill name and validate `name` and `description`
   front matter. The migration baseline is repository commit
   `45523d252a840ac8eec2775595831987aa4a1218`; deleted HM definitions can be
   inspected there if a historical source pin is needed.
7. Before replacing or deleting a live skill, record its path, source,
   revision/hash when known, content hash, reason, replacement, and rollback
   command. Restrict backups to a single resolved directory directly below
   `~/.agents/skills` or `~/.codex/skills`; never follow a symlink outside that
   root or back up general config. Store it under a mode-0700
   `~/.local/state/agent-skill-maintenance/backups/<timestamp>/` directory.
8. Validate the loader without a model call:

   ```bash
   codex debug prompt-input 'Discovery audit only; do not call tools.' \
     | jq -r '.. | strings | select(startswith("<skills_instructions>"))'
   ```

9. After Codex authentication is configured by the user, finish with an
   independent live probe. This is a networked model call and consumes API or
   subscription capacity; skip it until that boundary is intentionally ready:

   ```bash
   codex exec --ephemeral -s read-only -C "$PWD" --color never \
     'Do not call tools. List the expected personal skill names exposed in initial context.'
   ```

10. Re-run `./result/activate` only after another successful build. A second
   activation must not replace mutable skill directories with Nix-store links.
   The expected count of HM-owned links below `~/.agents/skills` is zero.

Codex plugin caches are not reconstruction targets. Reinstall the explicitly
enabled plugin set in `inventory.md` through Codex, then allow Codex to
select its supported cache version. Never copy a historical cache between
machines.

## Recovery limitations

This is a metadata-first recovery system. External skill bodies and plugin
caches are not mirrored. A vanished upstream revision or unpublished local
skill may therefore be unrecoverable unless it remains in Git history or a
separate canonical repository.
