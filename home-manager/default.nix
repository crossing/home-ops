{ inputs, ... }:
{
  flake.homeConfigurations."xing@desktop" = inputs.home-manager.lib.homeManagerConfiguration ({
    modules = [
      ({ ... }: {
        home.username = "xing";
        home.homeDirectory = "/home/xing";
      })
      ./home.nix
      ./zsh.nix
      ./git.nix
      ./ssh.nix
      ./desktop.nix
      ./aws.nix
      ./secrets.nix
      ./rclone.nix
      ./nix.nix
      inputs.sops-nix.homeManagerModule
    ];

    pkgs = import inputs.nixpkgs-unstable {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
  });
}
