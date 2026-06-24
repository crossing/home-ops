{ config, lib, pkgs, ... }:
{
  options.features.virtualisation.enable = lib.mkEnableOption "Enable virtualization configuration";

  config = lib.mkIf config.features.virtualisation.enable {
    virtualisation.spiceUSBRedirection.enable = true;

    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        runAsRoot = false;
      };
    };

    environment.systemPackages = with pkgs; [
      gnome-boxes
    ];

    users.users.${config.primaryUser}.extraGroups = [ "kvm" ];
  };
}
