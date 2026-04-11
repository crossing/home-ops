{ inputs, ... }:
{
  imports = [
    ./home.nix
    ./zsh.nix
    ./ssh.nix
    ./desktop.nix
    ./secrets.nix
    ./nix.nix
    ./apps
    ./developer
    ./ai
    ../../../modules/home/rclone.nix
    inputs.sops-nix.homeManagerModule
  ];

  home.enableNixpkgsReleaseCheck = false;
}
