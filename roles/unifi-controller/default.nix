{ inputs, ... }:
{
  flake.nixosModules.unifi-controller = { ... }: {
    imports = [
      ./unifi.nix
      ./nixpkgs.nix
    ];
  };
}
