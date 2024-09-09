{ stdenv
, lib
, fetchFromGitHub
, cmake
, curl
, gdal
, openscenegraph
, protobuf
, geos
, qtbase
, sqlite
, libzip
}:

stdenv.mkDerivation rec {
  pname = "osgearth";
  version = "3.2";

  src = fetchFromGitHub {
    owner = "gwaldron";
    repo = pname;
    rev = "${pname}-${version}";
    sha256 = "q6Mc6YxTO8wGgSgfCLp2ErkPeOuTlXvBQr0wENbUcv0=";
  };

  dontWrapQtApps = true;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ qtbase openscenegraph protobuf gdal geos sqlite curl ];

  enableParallelBuilding = true;

  outputs = [ "out" ];

  meta = with lib; {
    homepage = "https://osgearth.org";
    description = "osgEarth is a C++ geospatial SDK and terrain engine. Just create a simple XML file, point it at your map data, and go! osgEarth supports all kinds of data and comes with lots of examples to help you get up and running quickly and easily.";
    license = licenses.lgpl3;
    platforms = platforms.unix;
  };
}
