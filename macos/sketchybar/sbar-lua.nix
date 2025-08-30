{
  lib,
  stdenv,
  fetchFromGitHub,
  pkgs,
  ...
}:
stdenv.mkDerivation rec {
  pname = "SbarLua";
  version = "2024-08-21";

  src = fetchFromGitHub {
    owner = "FelixKratz";
    repo = pname;
    rev = "437bd2031da38ccda75827cb7548e7baa4aa9978";
    sha256 = "sha256-F0UfNxHM389GhiPQ6/GFbeKQq5EvpiqQdvyf7ygzkPg=";
  };

  buildInputs = with pkgs; [lua5_4 readline];
  nativeBuildInputs = with pkgs; [gcc];

  buildPhase = ''
    make
  '';

  installPhase = ''
    mkdir -p $out/lib/lua/5.4
    cp ./bin/sketchybar.so $out/lib/lua/5.4/
  '';

  meta = with lib; {
    description = "SketchyBar Lua Plugin";
    homepage = "https://github.com/FelixKratz/SbarLua";
    platforms = platforms.darwin;
  };
}
