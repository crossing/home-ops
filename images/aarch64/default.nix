{ withSystem, inputs, config, ... }:
{
  flake.images.aarch64 = withSystem "aarch64-linux"
    (
      { pkgs, ... }:
      inputs.nixos-generators.nixosGenerate {
        inherit pkgs;
        format = "sd-aarch64-installer";
        modules = [
          config.flake.nixosModules.server
        ];
      }
    );
}
