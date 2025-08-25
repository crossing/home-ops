{ lib, ... }:
{
  networking = {
    useDHCP = lib.mkForce true;
    hostName = "gk";
  };
}
