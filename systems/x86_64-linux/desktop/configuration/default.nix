{ inputs, system, config, ... }:
{
  imports = [
    ./main.nix
  ];

  nixpkgs.overlays = [
    inputs.self.overlays.unstable
    (self: super: {
      inherit (inputs.self.packages.${system}) pyroveil;
    })
  ];

  snowfallorg.users.${config.primaryUser}.home.enable = false;
}
