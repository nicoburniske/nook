{...}: {
  flake.modules.nixos.shadps4 = {pkgs, ...}: let
    shadps4PkgExtractor = pkgs.stdenv.mkDerivation {
      pname = "shadps4-pkg-extractor";
      version = "9d2e76127ce32d13192f9a6ab84a96404677394a";

      src = pkgs.fetchFromGitHub {
        owner = "AzaharPlus";
        repo = "shadPS4Plus";
        rev = "9d2e76127ce32d13192f9a6ab84a96404677394a";
        hash = "sha256-ml+k/S5H0XKsWWC935KL6a/JSlu9S4Td3z3STjnqu6s=";
      };

      nativeBuildInputs = [
        pkgs.cmake
        pkgs.pkg-config
      ];

      buildInputs = [
        pkgs.cryptopp
        pkgs.zlib
      ];

      sourceRoot = "source/extractor";

      postPatch = ''
        sed -i \
          -e "/add_library(libcryptopp STATIC IMPORTED)/d" \
          -e "/set_property(TARGET libcryptopp PROPERTY IMPORTED_LOCATION/d" \
          -e "s/target_link_libraries(pkg_extractor PRIVATE libcryptopp)/target_link_libraries(pkg_extractor PRIVATE cryptopp)/" \
          CMakeLists.txt
      '';

      installPhase = ''
        runHook preInstall
        install -Dm755 pkg_extractor $out/bin/pkg_extractor
        runHook postInstall
      '';
    };
  in {
    environment.systemPackages = [
      pkgs.shadps4-qtlauncher
      shadps4PkgExtractor
    ];
  };
}
