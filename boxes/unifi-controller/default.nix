{ ... }:
{
  modules = [
    ../../modules/ssh.nix
    ../../modules/unifi.nix
  ];

  format = "sd-aarch64";
  system = "aarch64-linux";
  hostname = "pi";
}
