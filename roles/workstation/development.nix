{ config, pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;

    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];
}
