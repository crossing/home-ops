{ config, lib, pkgs, ... }:
{
  imports = [
    ./codex.nix
    ./google.nix
    ./opencode.nix
  ];

  config = lib.mkIf config.profiles.personal.enable {
    # Skills are intentionally mutable under ~/.agents/skills. Home Manager
    # owns only the executables and non-FHS runtime dependencies they rely on.
    home.packages = [
      pkgs.agent-browser
      pkgs.rtk
    ];
  };
}
