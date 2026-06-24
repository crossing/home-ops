{ config, lib, pkgs, ... }:
{
  options.features.development = {
    enable = lib.mkEnableOption "Enable development tools";
    enableNvidiaContainer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable nvidia container toolkit for GPU development";
    };
  };

  config = lib.mkIf config.features.development.enable {
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;

      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    hardware.nvidia-container-toolkit.enable = config.features.development.enableNvidiaContainer;

    boot.binfmt.emulatedSystems = [
      "aarch64-linux"
    ];
  };
}
