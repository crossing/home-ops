{ withSystem, inputs, ... }:
{
  flake.images.unifi-controller = withSystem "aarch64-linux"
    (
      { pkgs, ... }:
      inputs.nixos-generators.nixosGenerate {
        inherit pkgs;
        format = "sd-aarch64";
        modules = [
          ../../roles/unifi-controller
        ];
      }
    );
}
