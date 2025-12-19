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
    inputs.sops-nix.homeManagerModule
  ];

  home.enableNixpkgsReleaseCheck = false;
}
