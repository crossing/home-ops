{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.programs.claude-wrapper;
in
{
  options.programs.claude-wrapper = {
    enable = mkEnableOption "Claude Code CLI wrapper (claudew)";

    package = mkOption {
      type = types.package;
      default = pkgs.claude-code;
      description = "The claude-code package to wrap.";
    };

    openrouterSecret = mkOption {
      type = types.str;
      default = "op://Op/OpenRouter/hermes";
      description = "1Password secret path for OpenRouter API key.";
    };

    models = {
      opus = mkOption {
        type = types.str;
        default = "openai/gpt-5.4-mini";
      };
      sonnet = mkOption {
        type = types.str;
        default = "openai/gpt-5.4-mini";
      };
      haiku = mkOption {
        type = types.str;
        default = "openai/gpt-5.4-nano";
      };
      subagent = mkOption {
        type = types.str;
        default = "openai/gpt-5.4-mini";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "claudew" ''
        if ! command -v op &> /dev/null; then
          echo "Error: 'op' command not found. Please install the 1Password CLI and ensure it matches the desktop app."
          exit 1
        fi

        export OPENROUTER_API_KEY=$(op read "${cfg.openrouterSecret}")
        export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
        export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
        export ANTHROPIC_API_KEY="" # Important: Must be explicitly empty
        export ANTHROPIC_DEFAULT_OPUS_MODEL="${cfg.models.opus}"
        export ANTHROPIC_DEFAULT_SONNET_MODEL="${cfg.models.sonnet}"
        export ANTHROPIC_DEFAULT_HAIKU_MODEL="${cfg.models.haiku}"
        export CLAUDE_CODE_SUBAGENT_MODEL="${cfg.models.subagent}"
        exec ${cfg.package}/bin/claude "$@"
      '')
    ];
  };
}
