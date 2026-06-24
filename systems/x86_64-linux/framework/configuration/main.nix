# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:
{
  imports =
    [
      ../../desktop/configuration/users.nix
      ../../desktop/configuration/desktop.nix
      ../../desktop/configuration/development.nix
      ../../desktop/configuration/printer-scanner.nix
      ../../desktop/configuration/virtualisation.nix
      ../../desktop/configuration/networking.nix
    ];

  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.
  users.users.${config.primaryUser}.extraGroups = [ "networkmanager" ];

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Disable Nvidia-specific settings from development module
  hardware.nvidia-container-toolkit.enable = lib.mkForce false;

  nix = {
    optimise.automatic = true;
    gc = {
      dates = "weekly";
      persistent = true;
      automatic = true;
    };
    settings = {
      max-jobs = "auto";
      cores = 0;
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  systemd.services.nix-generation-prune = {
    description = "Prune old NixOS generations";

    serviceConfig.Type = "oneshot";

    script = ''
      set -euo pipefail

      ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +5
    '';
  };

  systemd.timers.nix-generation-prune = {
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:crossing/home-ops#${config.networking.hostName}";
    dates = "Sun *-*-* 01:00:00";
  };

  services.fwupd.enable = true;
  programs.nix-ld.enable = true;
}
