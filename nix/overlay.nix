self: super: {
  nixos-generators = super.nixos-generators.overrideAttrs (old: {
    postPatch = ''
       ${if (old ? postPatch) then old.postPatch else ""}
       substituteInPlace nixos-generate \
                         --replace \
                         ' find "$out"' \
                         ' find "$out" ! -path "$out/nix-support/*"'

       substituteInPlace nixos-generate.nix \
                         --replace \
                         '? <nixpkgs>' \
                         '? (import <nixpkgs> { })'

       substituteInPlace nixos-generate.nix \
                         --replace \
                         'toString nixpkgs' \
                         'toString nixpkgs.path'

    '';
  });
}
