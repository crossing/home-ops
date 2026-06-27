{ pkgs }:
{
  codex = {
    packages = [
      pkgs.codex
      pkgs.codex-desktop
    ];
    configPath = ".codex/config.toml";
    skillDir = ".agents/skills";
  };

  hermes = {
    packages = [
      pkgs.hermes-agent
      pkgs.hermes-desktop
    ];
    configPath = ".hermes/config.toml";
    skillDir = ".hermes/skills";
  };

  agy = {
    packages = with pkgs; [
      antigravity
      google-cloud-sdk
    ];
    configPath = ".gemini/antigravity-cli/config.toml";
    skillDir = ".gemini/antigravity-cli/skills";
  };
}
