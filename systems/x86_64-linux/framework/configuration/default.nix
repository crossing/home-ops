{ inputs, system, config, ... }:
{
  imports = [
    ./main.nix
  ];

  profiles.gaming.enable = false;
  profiles.desktop.enable = true;

  snowfallorg.users.${config.primaryUser}.home.enable = false;
}
