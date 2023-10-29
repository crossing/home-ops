{ pkgs, config, ... }:
{
  virtualisation.spiceUSBRedirection.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      runAsRoot = false;
      ovmf.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    gnome.gnome-boxes
  ];

  users.users.${config.primaryUser}.extraGroups = [ "kvm" ];
}
