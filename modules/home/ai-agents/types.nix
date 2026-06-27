{ lib, pkgs }:
let
  inherit (lib) mkOption mkPackageOption types;

  skillSourceType = types.submodule {
    options = {
      library = mkOption {
        type = types.str;
        example = "github:addyosmani/agent-skills";
        description = "External skill library identifier.";
      };

      skillName = mkOption {
        type = types.str;
        example = "context-budgeting";
        description = "Skill name within the external library.";
      };

      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://github.com/addyosmani/agent-skills";
        description = "Human-readable upstream URL for update tracking.";
      };

      installCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "npx skill install github:addyosmani/agent-skills#context-budgeting";
        description = "Optional command-style install hint for this skill source.";
      };

      github = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            owner = mkOption {
              type = types.str;
              example = "addyosmani";
              description = "GitHub repository owner.";
            };

            repo = mkOption {
              type = types.str;
              example = "agent-skills";
              description = "GitHub repository name.";
            };

            rev = mkOption {
              type = types.str;
              description = "Pinned Git revision containing the skill.";
            };

            hash = mkOption {
              type = types.str;
              description = "Fixed-output hash for the fetched GitHub repository.";
            };

            path = mkOption {
              type = types.str;
              example = "skills/context-engineering/SKILL.md";
              description = "Path to the skill file within the fetched repository.";
            };
          };
        });
        default = null;
        description = "Pinned GitHub source for the skill text.";
      };

      file = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            url = mkOption {
              type = types.str;
              description = "Direct URL to a skill file.";
            };

            hash = mkOption {
              type = types.str;
              description = "Fixed-output hash for the fetched skill file.";
            };
          };
        });
        default = null;
        description = "Pinned direct URL source for the skill text.";
      };
    };
  };

  agentSkillOverrideType = types.submodule {
    options = {
      enable = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether this skill is enabled for this agent. Null inherits the skill default.";
      };

      title = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Agent-specific title override.";
      };

      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Agent-specific description override.";
      };

      bodyAppend = mkOption {
        type = types.lines;
        default = "";
        description = "Agent-specific Markdown appended to the shared skill body.";
      };

      packages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Extra packages required only for this agent's variant of the skill.";
      };
    };
  };
in
{
  skill = types.submodule ({ name, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this skill is enabled globally.";
      };

      title = mkOption {
        type = types.str;
        default = name;
        description = "Skill title written to SKILL.md.";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "Short skill description written to SKILL.md.";
      };

      body = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Optional inline Markdown body written to SKILL.md for local skills.";
      };

      source = mkOption {
        type = types.nullOr skillSourceType;
        default = null;
        description = "External skill library reference used instead of inline text.";
      };

      packages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Binary dependencies required by this skill.";
      };

      metadata = mkOption {
        type = types.attrsOf (types.oneOf [
          types.str
          (types.listOf types.str)
        ]);
        default = { };
        description = "Schema-friendly metadata for future external skill importers.";
      };

      agents = mkOption {
        type = types.attrsOf agentSkillOverrideType;
        default = { };
        description = "Per-agent skill overrides, including agent-specific skill packages.";
      };
    };
  });

  agent = types.submodule ({ name, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to install this agent and its enabled skills.";
      };

      package = mkPackageOption pkgs name {
        nullable = true;
        default = null;
      };

      packages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Packages installed for this agent itself.";
      };

      configPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = ".codex/config.toml";
        description = "Optional agent configuration path, relative to the home directory.";
      };

      skillDir = mkOption {
        type = types.str;
        example = ".codex/skills";
        description = "Directory where generated skills are installed, relative to the home directory.";
      };

      skillNames = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Additional skill names enabled for this agent.";
      };
    };
  });
}
