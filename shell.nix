{ pkgs ? import ./nix }:
pkgs.mkShell {
  name = "home-ops";

  buildInputs = [
    pkgs.nixos-generators
  ];
}
