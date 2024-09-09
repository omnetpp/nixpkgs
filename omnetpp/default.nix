{ lib, stdenv, fetchurl, gawk, file, which, bison, flex, perl, 
  python3,
  withIDE ? false, makeWrapper ? null,
  # glib, cairo, gsettings-desktop-schemas, gtk, swt, fontconfig,
  # freetype, libX11, libXrender, libXtst, webkitgtk, libsoup, atk, gdk-pixbuf,
  # pango, libglvnd, libsecret,
  graphviz ? null, doxygen ? null,
  withQTENV ? true, qtbase ? null, wrapQtAppsHook ? null,
  withOSG ? false, openscenegraph ? null, 
  withOSGEARTH ? false, osgearth ? null, 
  withLIBXML ? false, libxml2 ? null, zlib ? null,
  withPARSIM ? false, openmpi ? null, 
  preferSQLITE ? false,
  QT_STYLE_OVERRIDE ? "fusion",
}:

assert withIDE -> ! builtins.any isNull [ doxygen graphviz ];
assert withOSG -> ! isNull openscenegraph;
assert withOSGEARTH -> ! builtins.any isNull [ openscenegraph osgearth ];
assert withLIBXML -> ! builtins.any isNull [ libxml2 zlib ];
assert withPARSIM -> ! isNull openmpi;

with lib;
let
  qtbaseDevDirs =
    mapAttrsToList (n: _: n)
                   (filterAttrs (_: v: v == "directory")
                                (builtins.readDir (qtbase.dev + /include)));
  qtbaseCFlags =
    concatMapStringsSep " "
                        (x: "-isystem ${qtbase.dev + /include}/${x}")
                        qtbaseDevDirs;
  libxml2CFlags = "-isystem ${libxml2.dev}/include/libxml2";

  opp-python-dependencies = python-packages: with python-packages; [
    numpy
    pandas
    matplotlib
    scipy
    seaborn
    posix_ipc
  ]; 
  python3-with-opp-dependencies = python3.withPackages opp-python-dependencies;  

  OMNETPP_IMAGE_PATH = [ "./images"
                         "./bitmaps"
                         "${placeholder "out"}/share/images"
                       ];
in
stdenv.mkDerivation rec {
  pname = "omnetpp";
  version = "6.0";

  src = fetchurl {
    url = "https://github.com/omnetpp/omnetpp/releases/download/${pname}-${version}/${pname}-${version}-linux-x86_64.tgz";
    sha256 = "0gjclf0v92p6fxma22zib894yi71s473qm9d3fdlwrzrjx63yx3i";
  };

  outputs = [ "out" ];

  strictDeps = true;
  enableParallelBuilding = true;
  dontWrapQtApps = true;
  qtWrappersArgs = [ "--set QT_STYLE_OVERRIDE ${QT_STYLE_OVERRIDE}" ];

  inherit QT_STYLE_OVERRIDE OMNETPP_IMAGE_PATH;

  propagatedNativeBuildInputs = [ perl bison flex python3-with-opp-dependencies gawk which file ]
                             ++ optionals withQTENV [ wrapQtAppsHook ];

  nativeBuildInputs = optional withIDE [ makeWrapper ];

  propagatedBuildInputs = [ perl python3-with-opp-dependencies ]
                       ++ optionals withOSG [ openscenegraph ]
                       ++ optionals withOSGEARTH [ osgearth ]
                       ++ optionals withIDE [ graphviz doxygen ]
                       ++ optionals withPARSIM [ openmpi ];
  buildInputs = [  ]             
             ++ optionals withQTENV [ qtbase ]
             ++ optionals withIDE [ webkitgtk gtk
                                    fontconfig freetype libX11 libXrender
                                    glib gsettings-desktop-schemas swt cairo
                                    libsoup atk gdk-pixbuf pango libsecret
                                    libglvnd
                                  ] # some of them has been contained in propagatedbuildinputs
             ++ optionals withIDE [ graphviz doxygen ]
             ++ optionals withLIBXML [ zlib libxml2 ];

  NIX_CFLAGS_COMPILE = concatStringsSep " " [ qtbaseCFlags libxml2CFlags ];

  prePatch = ''
    patchShebangs src/utils
  '';

  patches = [ ];

  configureFlags = [ "OMNETPP_IMAGE_PATH=\"${concatStringsSep ";" OMNETPP_IMAGE_PATH}\""
                   ]
                   ++ optional (!withQTENV) "WITH_QTENV=no"
                   ++ optional (!withOSG) "WITH_OSG=no"
                   ++ optional (!withOSGEARTH) "WITH_OSGEARTH=no"
                   ++ optional withPARSIM "WITH_PARSIM=yes"
                   ++ optional withLIBXML "WITH_LIBXML=yes"
                   ++ optional preferSQLITE "PREFER_SQLITE_RESULT_FILES=yes";

  preConfigure = ''
       source setenv
    '';

  # Because omnetpp configure and makefile don't have install flag. In common,
  # all things run under omnetpp source directory. So I copy some file into out
  # directory by myself, but I don't know whether it can work or not.
  installPhase = ''
    runHook preInstall

    mkdir -p ${placeholder "out"}

    find samples -type d -name out | xargs rm -r

    installFiles=(lib bin include ide)
    for f in ''${installFiles[@]}; do
      cp -r $f ${placeholder "out"}
    done

    mkdir -p ${placeholder "out"}/share
    shareFiles=(Makefile.inc samples doc images)
    for f in ''${shareFiles[@]}; do
      cp -r $f ${placeholder "out"}/share
    done

    runHook postInstall
    '';

  preFixup = ''
    (
      build_pwd=$(pwd)
      for bin in $(find ${placeholder "out"} -type f -executable); do
        rpath=$(patchelf --print-rpath $bin  \
                | sed -E "s,$build_pwd,${placeholder "out"}:,g" \
               || echo )
        if [ -n "$rpath" ]; then
          patchelf --set-rpath "$rpath" $bin
        fi
      done
    )
    '';

  dontStrip = true;

  postFixup = ''
    ( # wrap ide
      if [ $withIDE = true ]; then
        cd ${placeholder "out"}/ide
        patchelf --set-interpreter ${stdenv.glibc.out}/lib/ld-linux*.so.2 ./opp_ide
        wrapProgram ${placeholder "out"}/ide/opp_ide \
          --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH" \
          --prefix LD_LIBRARY_PATH : ${makeLibraryPath (flatten []
                                        ++ optionals withIDE [ freetype fontconfig libX11 libXrender
                                          zlib glib gtk libXtst webkitgtk swt
                                          cairo libsoup atk gdk-pixbuf pango
                                          libglvnd libsecret
                                        ])}
      fi
    )
    for bin in $(find ${placeholder "out"}/share/samples -type f -executable); do
      wrapQtApp $bin \
        --set QT_STYLE_OVERRIDE ${QT_STYLE_OVERRIDE} \
        --prefix OMNETPP_IMAGE_PATH ";" "${concatStringsSep ";" OMNETPP_IMAGE_PATH}"
    done

    (
        cd ${placeholder "out"}/bin
        substituteInPlace opp_configfilepath \
          --replace ".." "../share"
    )
    wrapProgram ${placeholder "out"}/bin/omnetpp \
          --set GTK_THEME Awaita
    '';

  meta = with lib; {
    homepage= "https://omnetpp.org";
    description = "OMNeT++ is an extensible, modular, component-based C++ simulation library and framework, primarily for building network simulators.";
    license = licenses.unlicense;
    platforms = platforms.unix;
  };
}
