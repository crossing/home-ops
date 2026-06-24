{ inputs, ... }:
{
  imports = [
    (./. + "/../xing@desktop/home.nix")
    (./. + "/../xing@desktop/zsh.nix")
    (./. + "/../xing@desktop/ssh.nix")
    (./. + "/../xing@desktop/desktop.nix")
    (./. + "/../xing@desktop/secrets.nix")
    (./. + "/../xing@desktop/nix.nix")
    (./. + "/../xing@desktop/apps")
    (./. + "/../xing@desktop/developer")
    (./. + "/../xing@desktop/ai")

    inputs.sops-nix.homeManagerModule
  ];

  home.enableNixpkgsReleaseCheck = false;
}
