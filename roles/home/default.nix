{ inputs, ... }:
{
  flake.nixosModules.home-manager = { config, ... }: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];

    home-manager = {
      useGlobalPkgs = true;
      sharedModules = [ inputs.sops-nix.homeManagerModule ];
      users.${config.primaryUser} = import ./home.nix {
        username = config.primaryUser;
        home = config.users.users.${config.primaryUser}.home;
      };
    };
  };
}
