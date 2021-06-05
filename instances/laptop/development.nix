{ config, pkgs, ... }:
{
  virtualisation.docker.enable = true;
  users.users.${config.primaryUser}.extraGroups = [ "docker" ];
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];
}
