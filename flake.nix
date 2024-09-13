let
  nixosPkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-21.11.tar.gz" ) {};
in

{ pkgs ? nixosPkgs }:
let
  omnetppScope = with pkgs; {
    inherit (qt5) qtbase wrapQtAppsHook;
    inherit (xorg) libX11 libXrender libXtst;
    gtk = gtk3;
  } ;

  omnetppPkgs =  rec {
    callPackage = pkgs.newScope (omnetppScope // omnetppPkgs);
    # omnetpp = callPackage ./omnetpp { };
    # osgearth = callPackage ./3rdparty/osgearth { gdal = pkgs.gdal_2; };
    sewar = callPackage ./3rdparty/sewar {};
  };

in omnetppPkgs
