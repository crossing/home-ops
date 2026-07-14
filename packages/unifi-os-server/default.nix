{ lib, stdenvNoCC, fetchurl, coreutils, gnugrep, unzip }:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "unifi-os-server-installer";
  inherit (source) version;

  src = fetchurl {
    inherit (source) url hash;
  };

  dontUnpack = true;
  nativeBuildInputs = [ coreutils gnugrep unzip ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/unifi-os-server-installer"

    mapfile -t eocd_offsets < <(LC_ALL=C grep -aob $'PK\005\006' "$src" | cut -d: -f1)
    payload=
    for eocd in "''${eocd_offsets[@]}"; do
      entries=$(od -An -j $((eocd + 10)) -N 2 -tu2 "$src" | tr -d ' ')
      [[ "$entries" == 9 ]] || continue
      cd_size=$(od -An -j $((eocd + 12)) -N 4 -tu4 "$src" | tr -d ' ')
      cd_offset=$(od -An -j $((eocd + 16)) -N 4 -tu4 "$src" | tr -d ' ')
      archive_start=$((eocd - cd_size - cd_offset))
      archive_size=$((eocd + 22 - archive_start))
      ((archive_start >= 0)) || continue
      candidate="$TMPDIR/payload-$archive_start.zip"
      dd if="$src" of="$candidate" bs=1M iflag=skip_bytes,count_bytes \
        skip="$archive_start" count="$archive_size" status=none
      if unzip -t "$candidate" image.tar >/dev/null 2>&1; then
        payload=$candidate
        break
      fi
    done

    if [[ -z "$payload" ]]; then
      echo "could not locate installer payload containing image.tar" >&2
      exit 1
    fi

    install -d "$out/share/unifi-os-server"
    unzip -p "$payload" image.tar >"$out/share/unifi-os-server/image.tar"
    chmod 0444 "$out/share/unifi-os-server/image.tar"
    runHook postInstall
  '';

  passthru = {
    inherit (source) imageReference imageId;
    image = "${finalAttrs.finalPackage}/share/unifi-os-server/image.tar";
  };

  meta = {
    description = "Official Ubiquiti UniFi OS Server installer and OCI image";
    homepage = "https://www.ui.com/download/releases/unifi-os-server";
    license = lib.licenses.unfree;
    mainProgram = "unifi-os-server-installer";
    platforms = [ "x86_64-linux" ];
  };
})
