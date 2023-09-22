{ ... }:
{
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      buildInputs = [
        pkgs.deploy-rs
        pkgs.ssh-to-age
        pkgs.age
        pkgs.sops
      ];
    };
  };
}
