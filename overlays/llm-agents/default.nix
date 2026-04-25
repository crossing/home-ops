{ inputs, ... }:
self: super: {
  inherit (inputs.llm-agents.packages.${super.stdenv.hostPlatform.system})
    opencode
    oh-my-opencode
    claude-code
    hermes-agent
    agent-browser;
}
