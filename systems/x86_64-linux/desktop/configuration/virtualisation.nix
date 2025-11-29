{ pkgs, config, ... }:
{
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
}
