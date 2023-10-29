{ ... }:
{
  flake.nixosModules.workstation = { ... }: {
    imports = [
      ./main.nix
      ../common.nix
    ];
  };
}
