# Decisions

## 2026-07-12: skills are mutable; runtimes are declarative

The former `programs.aiAgents` module modeled, fetched, rewrote and linked skill
content. That coupling made routine ecosystem updates depend on Nix source
hashes and Home Manager activation. Skill content now lives in mutable agent
discovery roots, while Nix continues to provide executables and non-FHS
compatibility.

## 2026-07-12: metadata-only external recovery

The repository records provenance, revisions, content hashes and reinstall
guidance but does not mirror every upstream or plugin skill. Direct deletion is
allowed by the weekly review after metadata and rollback information are
recorded. This intentionally accepts that vanished upstream or unpublished
content may not always be recoverable.

## 2026-07-12: autonomous maintenance with reviewable Git writes

Weekly maintenance may add, update or delete mutable skills. It must validate
every mutation and restore the prior local copy on failure. It may not read or
alter secrets, authentication state, cookies, or browser profiles. Material
repository changes go to a dated branch and draft PR; the default branch is
never updated directly.

## 2026-07-12: reviews follow installed agents

Bootstrap and weekly review derive their targets from the agents installed by
the active Home Manager profile. Shared personal skills and each installed
agent's native roots are reviewed; absent agents are skipped. Exactly one agent
owns the weekly schedule to prevent duplicate maintenance runs.

## 2026-07-12: Codex workflows use true names and native orchestration

Codex's general workflow catalogue is intentionally small and progressively
loaded. Skill names and descriptions must match their bodies. Context control,
debugging, incremental edits, state transfer, parallel routing and the
goal-to-build cycle remain separate only where their triggers differ.

The Codex orchestration skills may use native goal, plan and subagent tools when
the current surface exposes them. They must not depend on absent `superpowers:*`
skills, generic legacy subagent syntax, recursive fan-out, or per-dispatch model
selection that the active tool surface cannot express. Read-heavy independent
work may run in parallel; shared live state and overlapping writes remain
sequential.

## 2026-07-12: larger coding work uses the Superpowers lane

`structured-build-cycle` remains the outer owner for the goal, authorization
boundary, route selection and final acceptance. Larger coding work delegates
design, detailed planning, implementation orchestration, TDD, review and branch
completion to the installed Superpowers plugin. The native plan tracks that as
one high-level unit and must not duplicate Superpowers' plan or dispatch loops.

The full lane is selected for cross-component behavior, API/schema/data-flow or
architectural changes, multiple independently verifiable coding tasks, broad
refactors/migrations, or an explicit request for the full Superpowers
development workflow. Localized fixes and
non-coding Nix, CI, packaging, documentation, skill/plugin and operational work
keep the compact native route, though individual Superpowers debugging, TDD or
verification skills may still apply.
