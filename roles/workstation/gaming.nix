{ config, lib, pkgs, ... }:
let
  renderingOffload = lib.mkIf (config.hardware.nvidia.prime.offload.enable) {
    __NV_PRIME_RENDER_OFFLOAD = 1;
    __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __VK_LAYER_NV_optimus = "NVIDIA_only";
  };
in
{
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraEnv = {
        MANGOHUD = true;
        OBS_VKCAPTURE = true;
        RADV_TEX_ANISO = 16;
      } // renderingOffload;
      extraLibraries = p: with p; [
        atk
        pyroveil
      ];
    };

    extest.enable = true;
  };
}
