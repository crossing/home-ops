{
  modules = [
    ../roles/ssh.nix
    ../roles/unifi.nix
  ];

  format = "sd-aarch64";
  system = "aarch64-linux";
  hostname = "pi";
}
