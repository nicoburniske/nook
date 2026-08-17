{pkgs, ...}: let
  inherit (pkgs) lib;
  src = ../../assets/fonts/BerkeleyMono;
in
  pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "berkeley-mono";
    version = "1.0";

    inherit src;

    installPhase = ''
      mkdir -p $out/share/fonts/opentype
      cp *.otf $out/share/fonts/opentype/
    '';

    passthru.faces =
      builtins.readDir src
      |> lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".otf" file)
      |> lib.mapAttrs' (file: _: let
        face = file |> lib.removePrefix "BerkeleyMono-" |> lib.removeSuffix ".otf";
      in
        lib.nameValuePair face "${finalAttrs.finalPackage}/share/fonts/opentype/${file}");

    meta = {
      description = "Berkeley Mono Font";
    };
  })
