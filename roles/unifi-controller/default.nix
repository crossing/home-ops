{ inputs, ... }:
{
  flake.nixosModules.unifi-controller = { ... }: {
    imports = [
      ../../modules/ssh.nix
      ../../modules/unifi.nix
      ./nixpkgs.nix
    ];
  };
}
