{ inputs, system, config, ... }:
{
  imports = [
    ./main.nix
  ];

  profiles.gaming.enable = true;
  profiles.desktop.enable = true;

  snowfallorg.users.${config.primaryUser}.home.enable = false;
}
