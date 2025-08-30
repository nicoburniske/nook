{pkgs, ...}:
pkgs.stdenv.mkDerivation {
  pname = "berkeley-mono";
  version = "1.0";

  src = ./fonts/BerkeleyMono;

  installPhase = ''
    mkdir -p $out/share/fonts/opentype
    cp *.otf $out/share/fonts/opentype/
  '';

  meta = {
    description = "Berkeley Mono Font";
  };
}
