{ inputs, ... }:
self: super: {
  inherit (inputs.codex-desktop-linux.packages.${super.stdenv.hostPlatform.system})
    codex-desktop;

  # Create Codex for Work by wrapping codex-desktop with a custom user data dir
  codex-desktop-work = self.stdenv.mkDerivation {
    pname = "codex-desktop-work";
    inherit (self.codex-desktop) version;

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [ self.makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin
      makeWrapper ${self.codex-desktop}/bin/codex-desktop $out/bin/codex-desktop-work \
        --add-flags "--user-data-dir=\$HOME/.config/CodexForWork"

      # Copy and adjust the desktop entry if it exists in the original package
      if [ -d ${self.codex-desktop}/share/applications ]; then
        mkdir -p $out/share/applications
        desktop_file=""
        if [ -f ${self.codex-desktop}/share/applications/codex-desktop.desktop ]; then
          desktop_file="codex-desktop.desktop"
        elif [ -f ${self.codex-desktop}/share/applications/codex.desktop ]; then
          desktop_file="codex.desktop"
        fi

        if [ -n "$desktop_file" ]; then
          cat ${self.codex-desktop}/share/applications/$desktop_file \
            | sed -e "s|Name=Codex Desktop|Name=Codex Desktop for Work|g" \
                  -e "s|codex-desktop.desktop|codex-desktop-work.desktop|g" \
                  -e "s|/bin/codex-desktop|/bin/codex-desktop-work|g" \
                  -e "s|Icon=codex-desktop|Icon=codex-desktop-work|g" \
                  -e "s|${self.codex-desktop}|$out|g" \
            > $out/share/applications/codex-desktop-work.desktop
        fi
      fi

      # Copy icons if they exist and name them codex-desktop-work
      if [ -d ${self.codex-desktop}/share/icons ]; then
        mkdir -p $out/share/icons
        cp -r ${self.codex-desktop}/share/icons/. $out/share/icons/
        chmod -R u+w $out/share/icons
        find $out/share/icons -name "codex-desktop.*" -o -name "codex.*" | while read icon; do
          dir=$(dirname "$icon")
          filename=$(basename "$icon")
          ext="''${filename##*.}"
          ln -s "$icon" "$dir/codex-desktop-work.''${ext}"
        done
      fi
    '';
  };
}
