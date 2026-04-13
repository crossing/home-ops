{ config, pkgs, ... }:
let
  sources = import ./nix/sources.nix;
  pruneScript = pkgs.writeShellScript "nix-generation-prune-home" ''
    set -euo pipefail

    mapfile -t generation_ids < <(
      ${config.programs.home-manager.package}/bin/home-manager generations \
        | ${pkgs.gawk}/bin/awk '$4 == "id" && $5 ~ /^[0-9]+$/ { print $5 }' \
        | ${pkgs.coreutils}/bin/sort -n
    )

    if [ "''${#generation_ids[@]}" -gt 10 ]; then
      remove_count=$(( ''${#generation_ids[@]} - 10 ))
      ${config.programs.home-manager.package}/bin/home-manager remove-generations "''${generation_ids[@]:0:remove_count}"
    fi
  '';
in
{
  programs.nix-index.enable = true;

  home.packages = [
    pkgs.nixVersions.nix_2_28
    pkgs.niv
    pkgs.nix-tree
    pkgs.nixpkgs-fmt
    pkgs.nixos-generators
    pkgs.nix-doc
  ];

  programs.zsh.plugins = [
    {
      name = "zsh-nix-shell";
      file = "nix-shell.plugin.zsh";
      src = sources.zsh-nix-shell;
    }
  ];

  systemd.user.services.nix-generation-prune = {
    Unit = {
      Description = "Prune old Home Manager generations";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pruneScript}";
    };
  };

  systemd.user.timers.nix-generation-prune = {
    Unit = {
      Description = "Weekly Home Manager generation pruning";
    };

    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
