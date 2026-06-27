{ inputs, ... }:
self: super: {
  inherit (inputs.codex-desktop-linux.packages.${super.stdenv.hostPlatform.system})
    codex-desktop;
}
