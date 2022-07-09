# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./boot.nix
      ./hardware-configuration.nix
      ./users.nix
      ./desktop.nix
      ./development.nix
    ];

  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/London";

  nix = {
    package = pkgs.nixVersions.nix_2_9;
    optimise.automatic = true;
    settings = {
      max-jobs = "auto";
      cores = 0;
    };
    extraOptions = ''
      experimental-features = nix-command
    '';
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  system.stateVersion = "22.05";
}

