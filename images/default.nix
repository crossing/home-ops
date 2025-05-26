{ withSystem, inputs, config, ... }:
let
  image = { system, format }:
    withSystem system
      (
        { pkgs, ... }:
        inputs.nixos-generators.nixosGenerate {
          inherit pkgs;
          inherit format;
          modules = [
            config.flake.nixosModules.server
          ];
        }
      );
in
{
  imports = [
    ../roles
  ];

  flake.installers = {
    x86_64 = image {
      system = "x86_64-linux";
      format = "install-iso";
    };

    aarch64 = image {
      system = "aarch64-linux";
      format = "sd-aarch64-installer";
    };
  };
}
