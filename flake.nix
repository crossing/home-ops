{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.05";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs.url = "github:serokell/deploy-rs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@args:
    let
      inherit (nixpkgs) lib;
      inputs = lib.filterAttrs (name: _: name != "self") args;
      hosts = import ./boxes inputs;
      images = import ./images inputs;
    in
    {
      inherit (hosts) nixosConfigurations deploy;
      inherit images;
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.deploy-rs
            pkgs.ssh-to-age
            pkgs.age
            pkgs.sops
          ];
        };
      });
}
