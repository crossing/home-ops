{ ... }:
{
  modules = [
    ../../roles/unifi-controller
  ];

  format = "sd-aarch64";
  system = "aarch64-linux";
  hostname = "pi";
}
