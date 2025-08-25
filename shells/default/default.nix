{ pkgs, mkShell, ... }:
mkShell {
  packages = [
    pkgs.deploy-rs
    pkgs.ssh-to-age
    pkgs.age
    pkgs.sops
  ];
}
