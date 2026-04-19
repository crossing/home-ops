{ config, lib, pkgs, ... }:

{
  options.home.autoUpgrade.enable = lib.mkEnableOption "Enable Home Manager auto-upgrade service";

  config = lib.mkIf config.home.autoUpgrade.enable {
    systemd.user.services.home-manager-upgrade = {
      Unit = {
        Description = "Home Manager Auto-Upgrade Service";
      };
      Service = {
        Type = "oneshot";
        # Fetch directly from GitHub and build home configuration
        ExecStart = ''${pkgs.home-manager}/bin/home-manager switch --flake github:crossing/home-ops'';
        # Don't fail if there are no changes
        RemainAfterExit = true;
        # Run with user's environment
        User = config.home.username;
      };
    };

    systemd.user.timers.home-manager-upgrade = {
      Unit = {
        Description = "Home Manager Auto-Upgrade Timer";
        RefuseManualStart = false;
        RefuseManualStop = false;
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
  };
}
