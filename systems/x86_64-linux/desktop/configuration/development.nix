{ config, pkgs, lib, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;

    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  hardware.nvidia-container-toolkit.enable = true;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];
}
