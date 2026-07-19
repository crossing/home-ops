{ inputs, ... }:
self: super: {
  inherit (inputs.llm-agents.packages.${super.stdenv.hostPlatform.system})
    opencode
    codex;
}
