{ config, pkgs, lib, ... }:
let
  docker = pkgs.docker.override rec {
    version = "27.4.0";
    mobyRev = "v${version}";
    mobyHash = "sha256-lhl4YkzOTTvddS4fleEif7z996yJ2ON6S1SnPU+owzM=";
    cliRev = "v${version}";
    cliHash = "sha256-q6xKERB5K7idExTrwFfX2ORs2G/55s2pybyhPcV5wuo=";
  };
in
{
  virtualisation.docker = {
    enable = true;
    package = docker;
    autoPrune.enable = true;

    rootless = {
      enable = true;
      setSocketVariable = true;
      package = docker;
    };
  };

  hardware.nvidia-container-toolkit.enable = true;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];
}
