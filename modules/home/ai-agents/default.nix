{ config, lib, pkgs, ... }:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    types;

  cfg = config.programs.aiAgents;
  defaultSkillSet = import ./default-skill-set.nix;
  optionTypes = import ./types.nix { inherit lib pkgs; };
  render = import ./render.nix { inherit lib pkgs cfg; };
in
{
  options.programs.aiAgents = {
    enable = mkEnableOption "AI agent packages and generated skills";

    defaultSkillSet = mkOption {
      type = types.listOf types.str;
      default = defaultSkillSet;
      example = literalExpression ''[ "context-budgeting" "targeted-code-navigation" ]'';
      description = "Skill names enabled for every enabled agent.";
    };

    agents = mkOption {
      type = types.attrsOf optionTypes.agent;
      default = { };
      description = "AI agents, their packages, config path, and skill installation path.";
    };

    skills = mkOption {
      type = types.attrsOf optionTypes.skill;
      default = { };
      description = "Reusable self-contained skills that can be installed for one or more agents.";
    };
  };

  config = mkIf cfg.enable {
    programs.aiAgents = {
      agents = import ./agents.nix { inherit pkgs; };
      skills = import ./skills.nix { inherit pkgs; };
    };

    home.packages = render.homePackages;
    home.file = render.homeFiles;
    home.activation.aiAgentsSkillDirMigration =
      config.lib.dag.entryBefore [ "linkGeneration" ] render.skillDirMigration;
  };
}
