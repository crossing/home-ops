{ nixos-generators, ... }:
{
  modules = [
    ../../roles/unifi-controller
  ];

  system = "aarch64-linux";
  format = "sd-aarch64";
}
