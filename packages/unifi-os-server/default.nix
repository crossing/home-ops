{ stdenv
, lib
, fetchurl
, unzip
, skopeo
}:

let
  version = "5.0.8";

  # Select URL and hash based on system architecture
  arch = stdenv.hostPlatform.system;

  sources = {
    "x86_64-linux" = {
      url = "https://fw-download.ubnt.com/data/unifi-os-server/c2e4-linux-x64-5.0.8-bcb62759-753a-4be2-8546-a6e0de63e59a.8-x64";
      sha256 = "db17656f222d371da5f96ed104e33503be16ca755817f126409b67d8009b1419";
    };
    "aarch64-linux" = {
      url = "https://fw-download.ubnt.com/data/unifi-os-server/5bdb-linux-arm64-5.0.8-a217d9c7-425d-4d05-847d-4122ff8edb2f.8-arm64";
      sha256 = "defe1e14bf84bd573ebbe2c96f015a9aed203e421df468705efcf42df8799a94";
    };
  };

  srcInfo = sources.${arch} or (throw "Unsupported system: ${arch}");
in
stdenv.mkDerivation rec {
  pname = "unifi-os-server-image";
  inherit version;

  src = fetchurl {
    url = srcInfo.url;
    sha256 = srcInfo.sha256;
  };

  nativeBuildInputs = [ unzip skopeo ];

  unpackPhase = "true";

  buildPhase = ''
    echo "Extracting image.tar from installer..."
    unzip $src image.tar || [ $? -eq 1 ]

    echo "Converting OCI archive image.tar to docker-archive..."
    # The output is a single tarball representing the docker-archive
    skopeo --tmpdir . --insecure-policy copy oci-archive:image.tar docker-archive:$out:unifi-os-server:${version}
  '';

  dontInstall = true;

  meta = with lib; {
    description = "Official UniFi OS Server container image, declarative package from Ubiquiti installer";
    homepage = "https://ui.com/download";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
