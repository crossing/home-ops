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
