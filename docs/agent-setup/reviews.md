# Weekly agent capability review

Run one review every Sunday at 10:00 Europe/London. Exactly one installed agent
owns the schedule; the review itself covers every agent installed by the active
Home Manager profile.

## Conditional targets

| Installed agent | Detection | Review roots | Native validation |
| --- | --- | --- | --- |
| Codex | `command -v codex` | `~/.agents/skills`, `~/.codex/skills`, enabled skill config, concrete plugin versions | `codex debug prompt-input`; optional ephemeral read-only probe |
| Hermes | `command -v hermes` | shared skills plus `~/.hermes/skills`; exclude curator backups/state | `hermes skills list`, `hermes skills check`, and `hermes skills audit` |
| Antigravity/Gemini | `command -v antigravity` | shared skills, `~/.gemini/antigravity-cli`, and enabled `~/.gemini/config/plugins` | validate front matter/resources and use an agent-native listing/probe when available |

Skip absent agents. When HM adds another agent, add its detection, roots,
ownership rules, and non-network validation here before the next review.

## Schedule bootstrap

When Codex is installed, create or update the project-scoped automation named
`Weekly agent capability maintenance` for this repository. Keep it active on
Sunday at 10:00 Europe/London and use the review contract below. If Codex is not
installed, use one installed agent's native scheduler with the same name,
cadence, working directory, and contract. Never create a second scheduler for
the same review.

After creation, read the scheduler state back and verify its name, active
status, project/working directory, cadence, and coverage. Bootstrap is
incomplete until this check succeeds.

## Review contract

1. Read this ledger, detect installed agents, and inventory their conditional
   targets using metadata only.
2. Check provenance, enabled state, upstream changes, supporting resources,
   native discovery, executable resolution, duplication, usefulness, and
   NixOS/non-FHS compatibility.
3. Mutable personal skills may be added, updated, or deleted when ownership and
   rationale are clear. Before mutation, record metadata and create a narrowly
   scoped, mode-0700, non-secret backup with an exact rollback command.
4. Do not mutate bundled skills, plugin caches, curator state, authentication,
   secrets, cookies, browser profiles, or unrelated configuration. Use the
   owning agent's installer for bundled/plugin capabilities.
5. Validate every mutation with the owning agent's native checks and restore on
   failure. Filesystem presence alone is not discovery evidence.
6. Propose Nix runtime changes in the retrospective/PR; never apply package,
   overlay, or runtime-input changes automatically.
7. Update `inventory.md` and the monthly retrospective. If material repository
   changes remain, use `codex/agent-setup-maintenance-YYYYMMDD`, commit and push
   only review files, and open a draft PR. Otherwise return a concise no-op
   health report.
