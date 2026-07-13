{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule
    ./ibkr.nix
  ];

  profiles.personal.enable = true;
  home.enableNixpkgsReleaseCheck = false;
}
