{ sops-nix, ... }:
{ config, lib, home-manager, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    sharedModules = [ sops-nix.homeManagerModule ];
    users.${config.primaryUser} = import ./home.nix {
      username = config.primaryUser;
      home = config.users.users.${config.primaryUser}.home;
    };
  };
}
