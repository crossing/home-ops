# Remove stale insecure MongoDB package

## Context

The `gk` host previously ran UniFi through the NixOS `services.unifi` module and explicitly selected `pkgs.mongodb-7_0`. Commit `7acbbe3` replaced that service with Ubiquiti's official UniFi OS container image. The repository no longer references the Nix MongoDB package, but it still imports MongoDB 7.0 from the `nixos-25.05` input and permits the insecure `mongodb-7.0.25` package globally.

## Design

Remove the obsolete `nixpkgs-old` flake input, the `overlays/mongodb` overlay, and the global `permittedInsecurePackages` exception. Regenerate `flake.lock` so the unused input is removed from the locked dependency graph.

Do not modify the UniFi container definition, its official image package, firewall rules, or `/var/lib/unifi` data volume. MongoDB bundled within the vendor image is outside the Nix package exception and remains managed by Ubiquiti's appliance image.

## Verification

1. Confirm no MongoDB, `nixpkgs-old`, or insecure-package references remain in repository configuration or the root lock graph.
2. Evaluate `nixosConfigurations.gk.config.system.build.toplevel` with a writable temporary Nix cache.
3. Build the `gk` system closure when dependencies and machine resources permit; if a full build is impractical, report the exact boundary and retain successful evaluation as the minimum acceptance evidence.
4. Confirm the resulting `gk` configuration still defines the UniFi OCI container and its image package.

## Acceptance criteria

- The insecure MongoDB package is no longer permitted or exposed by the repository.
- The obsolete `nixpkgs-old` input is absent from `flake.nix` and `flake.lock`.
- UniFi remains configured through the existing official container image.
- The `gk` NixOS configuration evaluates successfully.
