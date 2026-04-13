{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    nixpkgs-old.url = "nixpkgs/nixos-25.05";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs.url = "github:serokell/deploy-rs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    flake-parts.url = "github:hercules-ci/flake-parts";

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };


  outputs = { self, nixpkgs, llm-agents, ... }@inputs:
  let
    overlay-python-build = final: prev: {
      pyproject-nix = inputs.pyproject-nix;
      uv2nix = inputs.uv2nix;
      pyproject-build-systems = inputs.pyproject-build-systems;
    };

  in
  inputs.snowfall-lib.mkFlake {
    inherit inputs;
    src = ./.;

    channels-config = {
      allowUnfree = true;
    };

    overlays = [
      overlay-python-build
    ];

    deploy.nodes = nixpkgs.lib.mapAttrs
      (_: nixosConfiguration: {
        hostname = nixosConfiguration.config.networking.hostName;
        profiles.system = {
          user = "root";
          sshUser = "root";
          path = inputs.deploy-rs.lib.${nixosConfiguration.config.nixpkgs.hostPlatform.system}.activate.nixos nixosConfiguration;
        };
      })
      self.nixosConfigurations;
  };
}
