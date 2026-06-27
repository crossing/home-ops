{ inputs, ... }:
self: super: {
  inherit (inputs.llm-agents.packages.${super.stdenv.hostPlatform.system})
    hermes-agent
    codex;

  inherit (self.internal) hermes-desktop;
}
