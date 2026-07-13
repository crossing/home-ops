# Bootstrap agent capabilities

This procedure is designed to be handed to any capable maintenance agent.

1. Target `x86_64-linux`, user `xing`, with the repository cloned from
   `https://github.com/crossing/home-ops.git`. Read this directory and the
   repository `AGENTS.md`. Do not inspect or copy credentials, cookies,
   authentication state, or browser profiles.
2. Build the Home Manager target before changing live skills. `safe-cli` is a
   normal locked GitHub flake input and requires no local checkout:
   `nix build '.#homeConfigurations."xing@desktop".activationPackage' -L`.
3. Activate it with `./result/activate`, then confirm the Nix-owned runtime
   described in `nix-runtime.md`. Do not use
   global npm/pip installs or downloaded dynamically linked binaries as a
   substitute for missing Nix packages.
4. Determine which agents the activated HM profile installed, then use the
   conditional target matrix in `reviews.md`. Audit only roots belonging to
   installed agents, plus the shared `~/.agents/skills` root. Compare names,
   locations, source revisions, enabled state, and `sha256sum SKILL.md` with
   `inventory.md`.
5. Reinstall only missing mutable skills whose provenance is unambiguous.
   Preserve the installed skill name and validate `name` and `description`
   front matter. The migration baseline is repository commit
   `45523d252a840ac8eec2775595831987aa4a1218`; deleted HM definitions can be
   inspected there if a historical source pin is needed.
6. Before replacing or deleting a live skill, record its path, source,
   revision/hash when known, content hash, reason, replacement, and rollback
   command. Restrict backups to a single resolved directory directly below
   `~/.agents/skills` or `~/.codex/skills`; never follow a symlink outside that
   root or back up general config. Store it under a mode-0700
   `~/.local/state/agent-skill-maintenance/backups/<timestamp>/` directory.
7. Run each installed agent's native validation from `reviews.md`. For Codex,
   validate the loader without a model call:

   ```bash
   codex debug prompt-input 'Discovery audit only; do not call tools.' \
     | jq -r '.. | strings | select(startswith("<skills_instructions>"))'
   ```

8. After the relevant agent authentication is configured by the user, finish
   with an optional agent-native live probe. For Codex, this is a networked
   model call and consumes API or subscription capacity; skip it until that
   boundary is intentionally ready:

   ```bash
   codex exec --ephemeral -s read-only -C "$PWD" --color never \
     'Do not call tools. List the expected personal skill names exposed in initial context.'
   ```

9. Re-run `./result/activate` only after another successful build. A second
   activation must not replace mutable skill directories with Nix-store links.
   The expected count of HM-owned links below mutable skill roots is zero.
10. Enable the weekly review described in `reviews.md`. Prefer the Codex
    project automation when Codex is installed; otherwise use one installed
    agent's native scheduler. Create or update, never duplicate, the review and
    verify it is active for Sunday at 10:00 Europe/London.

Agent plugin caches and bundled skills are not reconstruction targets. Reinstall
the explicitly enabled set through its owning agent, then allow that agent to
select supported versions. Never copy a historical cache between machines.

## Recovery limitations

This is a metadata-first recovery system. External skill bodies and plugin
caches are not mirrored. A vanished upstream revision or unpublished local
skill may therefore be unrecoverable unless it remains in Git history or a
separate canonical repository.
