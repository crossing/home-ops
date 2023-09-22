{ ... }:
{
  flake.nixosModules.workstation = { ... }: {
    imports = [
      ./main.nix
    ];
  };
}
