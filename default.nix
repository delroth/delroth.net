{ stdenv, lib, hugo, self ? null }:

stdenv.mkDerivation {
  pname = "delroth-net-website";
  version = if self ? rev then self.rev else "dirty";

  src = lib.cleanSource ./.;

  nativeBuildInputs = [ hugo ];

  buildPhase = ''
    hugo --minify
  '';

  installPhase = ''
    mv public $out
  '';
}
