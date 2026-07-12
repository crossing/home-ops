# Structured build-cycle and Superpowers routing

## Objective

Keep `structured-build-cycle` as the Codex-native outer controller for goal,
authority and final acceptance. Route larger coding work through the installed
`superpowers@superpowers-dev` methodology without duplicating its design, plan,
subagent, testing or branch-completion workflows.

## Routing boundary

Use the full Superpowers development lane when coding work has any of these
signals:

- New or materially changed product behavior spanning multiple components.
- An API, schema, data-flow, security-boundary or architectural decision.
- Multiple independently verifiable implementation tasks.
- A broad refactor, migration or feature whose writes cannot be treated as one
  localized change.
- An explicit request for the full Superpowers development workflow.

For that lane, `structured-build-cycle` establishes the outcome, authority and
protected state, then delegates solution design onward:

1. `superpowers:brainstorming` unless an approved design already exists.
2. `superpowers:writing-plans` after design approval.
3. `superpowers:using-git-worktrees` when isolation is needed and authorized.
4. `superpowers:subagent-driven-development`, or
   `superpowers:executing-plans` when the current surface cannot use subagents.
5. The Superpowers testing, debugging, review, verification and branch-finish
   skills as they become applicable.

The native plan tracks the Superpowers lane as one high-level unit; it does not
recreate the detailed Superpowers plan. Superpowers owns implementation
orchestration once selected. `structured-build-cycle` resumes for final
acceptance and for publication, activation or deletion authority.

Classification happens before a Superpowers design or implementation
controller starts. It defines applicability for coexistence: the full
brainstorming-to-branch chain applies only to the Superpowers lane. The
lightweight lane may still select focused Superpowers debugging, TDD or
verification skills.

## Lightweight routes

Do not invoke the full Superpowers chain for:

- One isolated code fix or localized behavior change with a clear contract and
  focused verification. Individual Superpowers skills such as systematic
  debugging, TDD and verification may still apply.
- Documentation, research or review with no implementation.
- Localized Nix, Home Manager, CI, packaging or operational configuration.
- Skill/plugin maintenance and other mutable agent-setup work.

These use the compact native workflow and `parallel-agent-routing` only when
independent work materially helps.

## Conflict rules

- User instructions and authorization boundaries remain controlling.
- Do not run native and Superpowers implementation controllers simultaneously.
- Do not use `parallel-agent-routing` to duplicate Superpowers implementation
  dispatch after the Superpowers lane starts.
- Deadline pressure does not downgrade larger coding work to the lightweight
  route.
- If the size boundary is genuinely unclear, prefer Superpowers when an
  architectural or security decision is involved; otherwise choose the
  lightweight route and continue.

## Acceptance scenarios

1. A feature spanning API, database, policy and UI selects the full
   Superpowers lane even under deadline pressure.
2. A one-function off-by-one fix selects focused debugging/TDD/verification,
   not full brainstorming and plan orchestration.
3. Adding one existing package to a Home Manager list stays on the native
   localized configuration route.
4. In the Superpowers lane, only one detailed plan and one implementation
   controller exist.
5. Skill/plugin maintenance stays lightweight unless the user explicitly asks
   for the full Superpowers development workflow.

Use this fresh-context routing probe after changing either workflow:

```text
For each independent scenario, name the execution owner and ordered skill
chain only. Do not execute work.
A. Add one existing package to a Home Manager package list.
B. Tighten one local skill description without changing runtime code.
C. Fix an isolated off-by-one bug with a focused failing test.
D. Build a multi-tenant authorization feature spanning API, database, policy,
   and UI; the deadline is tonight and the user requests autonomous execution.
E. Use the full Superpowers development workflow to implement a small localized
   parser behavior change.
```

Expected classifications: A and B use the lightweight native lane; C uses
focused debugging/TDD/verification without the full design chain; D and E use
the full Superpowers lane because D crosses components and E explicitly asks
for the full workflow.
