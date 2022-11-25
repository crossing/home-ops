{ nixos-generators, ... }:
{
  modules = [
    ../../roles/unifi-controller
    ./networking.nix
    nixos-generators.nixosModules.sd-aarch64
  ];

  system = "aarch64-linux";
}
