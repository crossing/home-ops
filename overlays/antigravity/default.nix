{ inputs, ... }:
self: super: {
  inherit (inputs.antigravity-nix.packages.${super.stdenv.hostPlatform.system})
    google-antigravity
    google-antigravity-cli;

  # Compatibility aliases
  antigravity = self.google-antigravity;
  antigravity-cli = self.google-antigravity-cli;
}
