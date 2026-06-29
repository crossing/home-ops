{ pkgs }:
let
  library = {
    agentSkillsSpec = "https://github.com/agentskills/agentskills";
    anthropicSkills = "https://github.com/anthropics/skills";
    vercelSkills = "https://github.com/vercel-labs/skills";
    addyOsmaniAgentSkills = "https://github.com/addyosmani/agent-skills";
  };

  addyOsmani = {
    owner = "addyosmani";
    repo = "agent-skills";
    rev = "54c5adfc6b3b494b834d7c61a8feb41c9b5db083";
    hash = "0pxx4a61ngcvykmjk3dx4pviz4avpb0paiy88am8c2vnqgp8s02f";
  };

  rtk = {
    owner = "rtk-ai";
    repo = "rtk";
    rev = "d3553fb7ee45b901c46f6c063d8ea68ed0e96dfe";
    hash = "1fwbg0p4hmylx1ii9all4cjvk6x8idb2jzfqk4bqydg16sajni36";
  };

  robDefeoAgentSkills = {
    owner = "robdefeo";
    repo = "agent-skills";
    rev = "0b9da00edd625e9978e5f25813f95704e57600c7";
    hash = "0251c3w5dsb3p0wng7qbmp3li2ss7jwwf0bm20wjbd1xwk4can6c";
  };

  githubSkill = { source, skillName, path }: {
    library = "github:${source.owner}/${source.repo}";
    inherit skillName;
    url = "https://github.com/${source.owner}/${source.repo}/blob/${source.rev}/${path}";
    installCommand = "npx skill install github:${source.owner}/${source.repo}#${skillName}";
    github = source // { inherit path; };
  };
in
{
  context-budgeting = {
    title = "Context Budgeting";
    description = "Decide when to read, summarize, defer, or stop expanding context.";
    source = githubSkill {
      source = addyOsmani;
      skillName = "context-engineering";
      path = "skills/context-engineering/SKILL.md";
    };
    packages = [ ];
    metadata = {
      category = "token-efficiency";
      fallback-sources = [
        library.agentSkillsSpec
        library.anthropicSkills
      ];
      triggers = [ "large repositories" "unclear scope" "long files" ];
    };
  };

  targeted-code-navigation = {
    title = "Targeted Code Navigation";
    description = "Navigate code with focused search and local relationships instead of broad reads.";
    source = githubSkill {
      source = addyOsmani;
      skillName = "source-driven-development";
      path = "skills/source-driven-development/SKILL.md";
    };
    packages = [ pkgs.ripgrep ];
    metadata = {
      category = "token-efficiency";
      fallback-sources = [
        library.agentSkillsSpec
        library.anthropicSkills
      ];
      preferred-tools = [ "rg" "symbol search" "narrow file slices" ];
    };
  };

  command-output-discipline = {
    title = "Command Output Discipline";
    description = "Keep command output bounded and directly useful.";
    source = githubSkill {
      source = addyOsmani;
      skillName = "debugging-and-error-recovery";
      path = "skills/debugging-and-error-recovery/SKILL.md";
    };
    packages = [ ];
    metadata = {
      category = "token-efficiency";
      triggers = [ "build logs" "test logs" "search results" ];
    };
  };

  rtk-cli-output = {
    title = "RTK CLI Output";
    description = "Use RTK to reduce noisy CLI output before it reaches agent context.";
    body = ''
      ---
      name: rtk-cli-output
      description: Use RTK CLI wrappers to reduce noisy command output before it reaches Codex context. Use when running tests, builds, linters, package managers, git/GitHub commands, searches, logs, JSON inspection, container/Kubernetes commands, or other shell commands likely to produce long output where summarized failures, errors, or compact listings are enough.
      ---

      # RTK CLI Output

      RTK is a command-output proxy. It runs common CLI tools and emits compact, task-relevant output for agent context. In Codex, do not assume an automatic hook is active; call `rtk` explicitly when filtered output is useful.

      ## Core Rule

      Prefer `rtk <tool> ...` for commands that are likely to produce noisy output and where the next engineering step only needs a compact summary, failures, errors, changed lines, or grouped matches.

      Use the original command when exact output fidelity matters, such as interactive commands, prompts, snapshot text, generated artifacts, security-sensitive inspection, commands where every line may matter, or when the user explicitly asks to see raw output.

      ## Common Rewrites

      Use these direct wrappers instead of the raw command:

      ```bash
      rtk git status
      rtk git diff
      rtk git log -n 20
      rtk gh pr view 123
      rtk gh run view --log

      rtk cargo test
      rtk cargo build
      rtk cargo clippy
      rtk pytest
      rtk go test ./...
      rtk jest
      rtk vitest
      rtk playwright test

      rtk tsc
      rtk lint
      rtk prettier --check .
      rtk ruff check
      rtk mypy

      rtk pnpm install
      rtk npm install
      rtk pip list

      rtk grep "pattern" .
      rtk find "*.nix" .
      rtk json file.json
      rtk log app.log
      rtk docker ps
      rtk kubectl get pods
      ```

      For commands without a dedicated wrapper:

      ```bash
      rtk test <command>     # tests: show failures
      rtk err <command>      # builds/tools: show errors and warnings
      rtk summary <command>  # heuristic summary
      rtk proxy <command>    # raw passthrough with RTK tracking
      ```

      For existing output on stdin:

      ```bash
      long-command | rtk pipe
      long-command | rtk pipe -f cargo-test
      ```

      ## Workflow

      1. Before running a noisy command, choose the closest RTK wrapper.
      2. If RTK output is sufficient, proceed from the compact result.
      3. If RTK reports a full-output path, read that saved log instead of rerunning the command unless rerun behavior is required.
      4. If the compact output hides needed detail, rerun the original command or use `rtk proxy <command>`.
      5. If unsure how RTK would rewrite a command, inspect it with `rtk rewrite '<command>'`; treat a nonzero status with printed rewrite text as informational.

      ## Caveats

      - RTK intentionally filters output. Do not use it when preserving exact stdout/stderr is the task.
      - RTK's Codex setup is instruction-based (`rtk init -g --codex` writes AGENTS.md/RTK.md); this skill is the runtime reminder to use explicit wrappers.
      - Do not run `rtk init`, `rtk trust`, `rtk untrust`, or `rtk telemetry` unless the user asks for RTK setup/configuration work.
      - `rtk --ultra-compact` can reduce output further, but avoid it when filenames, line numbers, or grouped context are needed for a fix.
    '';
    source = githubSkill {
      source = rtk;
      skillName = "quick-start";
      path = "docs/guide/getting-started/quick-start.md";
    };
    packages = [ pkgs.rtk ];
    metadata = {
      category = "token-efficiency";
      tool = "rtk";
      triggers = [ "long command output" "test output" "build output" "search output" ];
    };
  };

  incremental-editing = {
    title = "Incremental Editing";
    description = "Make small localized edits while preserving unrelated user changes.";
    source = githubSkill {
      source = addyOsmani;
      skillName = "incremental-implementation";
      path = "skills/incremental-implementation/SKILL.md";
    };
    packages = [ ];
    metadata = {
      category = "token-efficiency";
      fallback-sources = [
        library.agentSkillsSpec
        library.anthropicSkills
      ];
      triggers = [ "dirty worktree" "small fixes" "merge conflicts" ];
    };
  };

  state-and-handoff = {
    title = "State And Handoff";
    description = "Maintain compact task state and avoid repeating already-known context.";
    source = githubSkill {
      source = addyOsmani;
      skillName = "planning-and-task-breakdown";
      path = "skills/planning-and-task-breakdown/SKILL.md";
    };
    packages = [ ];
    metadata = {
      category = "token-efficiency";
      fallback-sources = [
        library.agentSkillsSpec
        library.anthropicSkills
      ];
      triggers = [ "resume" "handoff" "long task" ];
    };
  };

  para-second-brain = {
    title = "PARA Second Brain";
    description = "Organize, classify, and maintain a PARA-method second brain.";
    source = githubSkill {
      source = robDefeoAgentSkills;
      skillName = "para-second-brain";
      path = "skills/para-second-brain";
    };
    packages = [ ];
    metadata = {
      category = "knowledge-management";
      methodology = [ "PARA" "second brain" ];
      upstream-installs = "356";
      triggers = [
        "where to file something"
        "process inbox"
        "monthly review"
        "validate second brain structure"
      ];
    };
  };
}
