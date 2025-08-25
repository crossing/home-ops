# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  imports =
    [
      ./users.nix
      ./desktop.nix
      ./development.nix
      ./printer-scanner.nix
      ./virtualisation.nix
      ./networking.nix
    ];

  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.
  users.users.${config.primaryUser}.extraGroups = [ "networkmanager" ];

  # Set your time zone.
  time.timeZone = "Europe/London";

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

  system.autoUpgrade = {
    enable = true;
    flake = "github:crossing/home-ops#${config.networking.hostName}";
    dates = "Sun *-*-* 01:00:00";
  };

  services.fwupd.enable = true;
  programs.nix-ld.enable = true;
}
