# IBKR Gateway 2FA Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make stalled IB Key push authentication actionable while retaining ordered Gateway coordination.

**Architecture:** Extend the existing shell coordinator with immediate, secret-free diagnostic output when an active profile is not API-ready. Keep the repository-local investment skill as the concise operational runbook for attaching to the headless Gateway dialog and using Challenge/Response.

**Tech Stack:** Bash, systemd user services, Podman/Xvfb, `xdotool`, ImageMagick, Markdown skills.

## Global Constraints

- Keep `ibkr-gateway-ensure-live` as the normal ordered entry point.
- Prefer primary command `ibkr`; retain `ibkr-local` compatibility.
- Never print credentials, generated IBC configuration, account data, or 1Password session state.
- Never hard-code Gateway UI coordinates; capture and inspect before clicking.
- Preserve unrelated work in both repositories.

---

### Task 1: Coordinator diagnostics

**Files:**
- Modify: `modules/home/ibkr-local/test-ibkr-gateway-ensure.sh`
- Modify: `modules/home/ibkr-local/ibkr-gateway-ensure.sh`

**Interfaces:**
- Consumes: `ibkr connect --profile PROFILE`, `systemctl --user`, existing per-profile reauthentication helpers.
- Produces: immediate stderr diagnostics when a profile is active but not API-ready.

- [ ] **Step 1: Write the failing test**

Assert the unready-profile case includes `Second Factor Authentication`, `Challenge/Response`, `Services -> Authenticate`, and the profile's service name in stderr.

- [ ] **Step 2: Verify RED**

Run: `bash modules/home/ibkr-local/test-ibkr-gateway-ensure.sh`

Expected: FAIL because the existing coordinator only reports readiness timeout.

- [ ] **Step 3: Implement minimal output**

Add a small `print_auth_diagnostics PROFILE SERVICE` function, prefer `ibkr` with an `ibkr-local` fallback, and call the function once when the first readiness probe fails.

- [ ] **Step 4: Verify GREEN**

Run: `bash modules/home/ibkr-local/test-ibkr-gateway-ensure.sh`

Expected: `PASS: ibkr-gateway-ensure coordinator`.

### Task 2: Investment bootstrap skill

**Files:**
- Modify: `/home/xing/works/home/investment/.agents/skills/bootstrap-ibkr-gateway/SKILL.md`
- Review: `/home/xing/works/home/investment/.agents/skills/bootstrap-ibkr-gateway/agents/openai.yaml`

**Interfaces:**
- Consumes: coordinator diagnostics and a running headless Gateway service.
- Produces: coordinator-first diagnosis and challenge/response instructions.

- [ ] **Step 1: Update the skill**

Use `ibkr` for connectivity checks, retain `ibkr-local` compatibility wording, add the service/journal decision tree, headless X attachment procedure, capture-before-click rule, and IBKR Mobile challenge/response steps.

- [ ] **Step 2: Validate**

Run `quick_validate.py` against the skill directory and confirm `agents/openai.yaml` still describes the skill accurately.

### Task 3: Integrated verification

**Files:**
- Review all modified files in both repositories.

- [ ] **Step 1: Run checks**

Run the focused coordinator test, `bash -n` on changed shell files, `git diff --check`, the relevant Nix build, and read-only `ibkr connect` checks for `main-live` and `pension-live`.

- [ ] **Step 2: Review diffs**

Confirm no secrets, hard-coded coordinates, unrelated edits, or activation changes were introduced.
