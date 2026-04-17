{ inputs, ... }:
self: super: {
  inherit (inputs.llm-agents.packages.${super.system})
    opencode
    oh-my-opencode
    claude-code
    hermes-agent;
}
