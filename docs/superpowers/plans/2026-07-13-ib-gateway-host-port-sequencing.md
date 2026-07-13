# IB Gateway Host-Port Sequencing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run both live Gateways reliably on host networking without using IBKR's default API ports or starting two sessions before the first is API-ready.

**Architecture:** Restore `--net=host`, assign non-default unique ports to all profiles, stagger live IBC restarts, and make the existing coordinator gate each next start on a successful constrained API handshake. Preserve all existing data, credential, and order-safety boundaries.

**Tech Stack:** Nix, Home Manager, Bash, Podman host networking, systemd user services, IBC 3.24.1.

## Global Constraints

- Work only in `/tmp/home-ops-ibkr-gateway` on `feature/ibkr-local-integration`.
- Do not restart live services until focused tests and all Nix builds pass.
- Never print credentials, OTPs, account identifiers, financial rows, generated IBC configuration, or scoped 1Password session values.
- Preserve submit, cancel, and modify blocking in `ibkr-local`.
- Start `main-live` before `pension-live`; never start the second after the first profile fails readiness.

---

### Task 1: Define the failing host-port contract

**Files:**
- Modify: `packages/ibgateway/test-network-isolation.sh`
- Create: `homes/x86_64-linux/xing@desktop/test-ibkr-ports.sh`

**Interfaces:**
- Consumes: `packages/ibgateway/wrapper.sh` and `homes/x86_64-linux/xing@desktop/ibkr.nix`.
- Produces: tests requiring `--net=host`, unique ports 4005/4006/4003/4004, and no profile on 4001 or 4002.

- [ ] Replace the bridge assertion with a host-network assertion and run it; require failure while the wrapper still configures bridge publication.
- [ ] Add a profile-port test that extracts the four named profile blocks and asserts exact unique non-default ports; run it and require failure on the current 4001/4002 assignments.
- [ ] Commit both red tests as `test(ibkr): cover host port discipline`.

### Task 2: Define the failing sequential-readiness contract

**Files:**
- Modify: `modules/home/ibkr-local/test-ibkr-gateway-ensure.sh`

**Interfaces:**
- Consumes: coordinator arguments as ordered `PROFILE` names and `IBKR_GATEWAY_READY_TIMEOUT` for a short test timeout.
- Produces: proof that `ibkr-local connect --profile PROFILE` gates the next helper and that failure leaves later profiles inactive.

- [ ] Add a fake `ibkr-local` readiness command and event log.
- [ ] Assert an active-but-unready first profile fails without invoking the second helper.
- [ ] Assert two missing profiles produce events `start main-live`, `ready main-live`, `start pension-live`, `ready pension-live` in that order.
- [ ] Run the test and require failure because the current coordinator checks only service activity.
- [ ] Commit the red test as `test(ibkr): require sequential gateway readiness`.

### Task 3: Implement host ports and sequencing

**Files:**
- Modify: `packages/ibgateway/wrapper.sh`
- Modify: `homes/x86_64-linux/xing@desktop/ibkr.nix`
- Modify: `modules/home/ibkr-local/default.nix`
- Modify: `modules/home/ibkr-local/ibkr-gateway-ensure.sh`

**Interfaces:**
- Consumes: ordered profile names, `ibkr-local connect`, and optional `IBKR_GATEWAY_READY_TIMEOUT`/`IBKR_GATEWAY_READY_INTERVAL` positive integers.
- Produces: host-network containers and serialized API-ready live startup.

- [ ] Restore `--net=host` and remove the bridge-only `IBKR_API_PORT` wrapper contract.
- [ ] Configure ports 4005/4006/4003/4004 and live restarts at 11:35 PM/11:55 PM.
- [ ] Add a bounded readiness poll after each service start or already-active check; stop processing immediately on failure or timeout.
- [ ] Run all three focused tests plus Bash syntax checks and require PASS.
- [ ] Commit as `fix(ibkr): serialize gateways on non-default ports`.

### Task 4: Build, activate, and prove coexistence

**Files:**
- Modify: `HANDOFF-ibkr-gateway-runtime.md`

**Interfaces:**
- Consumes: verified packages, Home Manager generation, reauthentication helpers, and manual broker-offered IB Key approval.
- Produces: authenticated live listeners and API handshakes on 4005 and 4003.

- [ ] Build `ibgateway`, `ibkr-local`, and `homeConfigurations."xing@desktop".activationPackage`; run the autorestart parser test, focused tests, syntax checks, and `git diff --check`.
- [ ] Back up and replace only the generated IBKR unit links, then reload the user manager.
- [ ] Reauthenticate `main-live`, require API readiness on 4005, then reauthenticate `pension-live` and require both API handshakes.
- [ ] Verify separate data/runtime paths, staggered restart config, absent service session secrets, and fail-closed order mutation without printing protected values.
- [ ] Update the handoff and commit as `docs(ibkr): record sequenced dual gateway proof`.
