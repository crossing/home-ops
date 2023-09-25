{ inputs, ... }:
{
  flake.nixosModules.server = { ... }: {
    imports = [
      ./ssh.nix
    ];
  };
}
