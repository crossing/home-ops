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
    ./rclone.nix
    ./nix.nix
    ./emacs.nix
    inputs.sops-nix.homeManagerModule
  ];

  home.enableNixpkgsReleaseCheck = false;
}
