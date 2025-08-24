{ inputs, ... }:
{
  imports = [
    ./ssh.nix
    inputs.self.nixosModules.common
  ];
}
