{ config, lib, pkgs, ... }:
{
  imports = [
    ./unifi.nix
  ];

  services.local-dns = {
    enable = true;
    mappings = {
      "7c:83:34:b5:82:19" = "gk";
      "2c:6f:c9:3b:fc:e7" = "printer";
    };
  };
}
