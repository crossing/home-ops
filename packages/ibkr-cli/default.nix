{ lib, inputs, pkgs, stdenv, ... }:

let
  pyproject-nix = inputs.pyproject-nix;
  uv2nix = inputs.uv2nix;
  pyproject-build-systems = inputs.pyproject-build-systems;
  
  # Read metadata from metadata.json (in store after git add)
  metadata = lib.importJSON ./metadata.json;
  
  src = pkgs.fetchFromGitHub {
    owner = metadata.owner;
    repo = metadata.repo;
    rev = metadata.rev;
    hash = metadata.narHash;
  };
  
  # Combine src with local uv.lock - need to put uv.lock inside src directory
  src-with-lock = pkgs.runCommand "ibkr-cli-src" {} ''
    mkdir -p $out
    cp -r ${src}/* $out/
    cp ${./uv.lock} $out/uv.lock
  '';
  
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = src-with-lock;
  };
  
  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };
  
  python = pkgs.python3;
  
  pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; })
    .overrideScope (lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      overlay
    ]);

  env = pythonSet.mkVirtualEnv "ibkr-cli-env" workspace.deps.default;

in
pkgs.writeShellApplication {
  name = "ibkr";
  runtimeInputs = [ env ];
  text = ''
    exec python -m ibkr_cli.app "$@"
  '';
}