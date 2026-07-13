# IB Gateway Network Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each live Gateway an isolated network namespace while exposing only its configured API port on host loopback.

**Architecture:** Replace host networking with Podman's bridge mode and an explicit `127.0.0.1:PORT:PORT/tcp` publish rule. Pass the already configured profile port from the Home Manager run script into the Gateway wrapper; keep every existing data and credential boundary unchanged.

**Tech Stack:** Nix, Home Manager, Bash, Podman rootless bridge networking, systemd user services, IBC 3.24.1.

## Global Constraints

- Work only in `/tmp/home-ops-ibkr-gateway` on `feature/ibkr-local-integration`.
- Do not restart live services until the focused test and all Nix builds pass.
- Never print credentials, OTPs, account identifiers, financial rows, generated IBC configuration, or scoped 1Password session values.
- Keep API publication bound to `127.0.0.1`; do not expose Gateway ports on all host interfaces.
- Preserve submit/cancel/modify blocking in `ibkr-local`.

---

### Task 1: Test the network argument contract

**Files:**
- Create: `packages/ibgateway/test-network-isolation.sh`

**Interfaces:**
- Consumes: `packages/ibgateway/wrapper.sh`.
- Produces: exit 0 only when `configure_network PORT` appends bridge mode and the exact loopback publish rule, while invalid ports fail.

- [ ] Write a test that extracts `configure_network` from the real wrapper, invokes it for 4001 and 4003, and asserts arrays equal:

```text
--network=bridge
--publish
127.0.0.1:4001:4001/tcp
```

and the equivalent 4003 mapping. Assert ports `0`, `65536`, and `not-a-port`
fail, and assert the wrapper contains no `--net=host` or `--network=host`.

- [ ] Run `bash packages/ibgateway/test-network-isolation.sh` and require a
failure because `configure_network` does not exist and host networking remains.

- [ ] Commit the red test as `test(ibkr): cover gateway network isolation`.

---

### Task 2: Implement isolated bridge networking

**Files:**
- Modify: `packages/ibgateway/wrapper.sh`
- Modify: `modules/home/ibkr-local/default.nix`

**Interfaces:**
- Consumes: `IBKR_API_PORT`, generated from `profile.port`.
- Produces: `--network=bridge --publish 127.0.0.1:PORT:PORT/tcp` for each IBC Gateway container.

- [ ] Add `IBKR_API_PORT` to wrapper usage and parse it as `API_PORT`.
- [ ] Add `configure_network`, validating the range 1-65535 and requiring a
port in IBC mode.
- [ ] Remove `--net=host`, call `configure_network "$API_PORT"`, and preserve
all existing mount, Xvfb, container-name, and cleanup arguments.
- [ ] Export `IBKR_API_PORT=${toString profile.port}` from the generated
per-profile run script.
- [ ] Run the focused test, `bash -n` on affected scripts, and
`git diff --check`; commit as `fix(ibkr): isolate gateway networks`.

---

### Task 3: Build and prove dual-live runtime isolation

**Files:**
- Modify: `HANDOFF-ibkr-gateway-runtime.md`

**Interfaces:**
- Consumes: the verified Home Manager generation and existing reauth helpers.
- Produces: two authenticated, independently networked Gateway containers with working loopback API ports.

- [ ] Build `ibgateway`, `ibkr-local`, and
`homeConfigurations."xing@desktop".activationPackage`; run the coordinator,
autorestart-parser, network-isolation, syntax, whitespace, and fail-closed
submit tests.
- [ ] Replace only the two manually managed IBKR unit links, retaining
`/tmp/ibkr-unit-links-before-autorestart-fix` as rollback state, then reload
the user manager.
- [ ] Reauthenticate `main-live` and `pension-live` in one persistent local
1Password shell and complete broker-offered IB Key challenges manually.
- [ ] Confirm distinct container network namespace IDs, loopback listeners on
4001 and 4003, successful constrained API handshakes, stable coordinator IDs,
0600 credential files, and absent `OP_SESSION_*`/`OP_ACCOUNT` service values.
- [ ] Reduce positions, balances, and executions locally to row counts only;
do not emit source JSON.
- [ ] Update the handoff, run final verification, and commit as
`docs(ibkr): record isolated dual gateway proof`.
