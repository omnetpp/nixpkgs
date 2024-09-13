{ pkgs ? import <nixpkgs> {} }:

pkgs.python3Packages.buildPythonPackage rec {
  pname = "sewar";
  version = "0.4.6";
  pyproject = true;

  # Specify source of the package. It can be a Git repo, a local directory, or a tarball
  # src = https://github.com/andrewekhalel/sewar;

  src = pkgs.fetchFromGitHub {
    owner = "andrewekhalel";
    repo = "sewar";
    rev = "d2fd6805e8dc812483a86ae231d8a5685dffdf38";  # Replace with the actual tag or commit hash
    sha256 = "sha256-yV8MY1Iaw1tyxt1/Y2RYY67vjmnOYQLjPu6l2vDRbfw=";  # Replace with actual SHA256 hash
  };

  # Specify Python package dependencies
  propagatedBuildInputs = [ 
    pkgs.python3Packages.numpy
    pkgs.python3Packages.scipy
    pkgs.python3Packages.pillow
    pkgs.python3Packages.nose
  ];

  # Meta information about the package
  meta = with pkgs.lib; {
    description = "A short description of your package";
    license = licenses.mit;  # Adjust this to your actual license
  };
}