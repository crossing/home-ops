{ ... }:
{
  system.stateVersion = "23.05";

  nixpkgs.config = {
    allowUnfree = true;
  };
}
