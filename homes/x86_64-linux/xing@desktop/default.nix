{ inputs, ... }:
{
  imports = [
    ./home.nix
    ./zsh.nix
    ./git.nix
    ./ssh.nix
    ./desktop.nix
    ./aws.nix
    ./secrets.nix
    ./nix.nix
    ./emacs.nix
    ./apps
    ../../../modules/home/rclone.nix
    inputs.sops-nix.homeManagerModule
  ];

  home.enableNixpkgsReleaseCheck = false;
}
