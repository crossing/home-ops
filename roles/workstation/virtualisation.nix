{ pkgs, ... }:
{
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
}
