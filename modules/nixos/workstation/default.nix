{ inputs, system, ... }:
{
  imports = [
    ./main.nix
    inputs.self.nixosModules.common
  ];

  nixpkgs.overlays = [
    inputs.self.overlays.unstable
    (self: super: {
      inherit (inputs.self.packages.${system}) pyroveil;
    })
  ];
}
