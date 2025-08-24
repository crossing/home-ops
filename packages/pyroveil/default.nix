{ fetchFromGitHub
, stdenv
, lib
, cmake
, ninja
, python3
}:
stdenv.mkDerivation rec {
  name = "pyroveil-${version}";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "HansKristian-Work";
    repo = "pyroveil";
    rev = "e236fb4";
    sha256 = "sha256-YjnvF7t44Xa21X1nfmkF+0Eqy4V2u0vuVMIPmAVZHRk=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake ninja python3 ];

  postPatch = ''
    substituteInPlace layer/CMakeLists.txt \
      --replace "\''${CMAKE_INSTALL_PREFIX}/\''${CMAKE_INSTALL_LIBDIR}" "\''${CMAKE_INSTALL_FULL_LIBDIR}"
  '';
}
