{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModule
  ];

  profiles.personal.enable = true;
  home.enableNixpkgsReleaseCheck = false;
}
