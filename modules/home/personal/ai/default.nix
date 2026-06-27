{ config, lib, ... }:
lib.mkIf config.profiles.personal.enable {
  programs.aiAgents.enable = true;

  programs.antigravity-cli = {
    enable = true;
  };
}
