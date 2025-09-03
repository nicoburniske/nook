{ pkgs, ... }:

let
  comically = pkgs.rustPlatform.buildRustPackage {
    pname = "comically";
    version = "0.1.6";

    src = pkgs.fetchFromGitHub {
      owner = "nicoburniske";
      repo = "comically";
      rev = "dc690a3a93a962e29fc476b4b40cc5d0d2cb1907";
      hash = "sha256-imW0tY0Qi/HDQS0drv/38K5eWJoCAYWIb/TgpXosWIY=";
    };

    cargoHash = "sha256-RGYeYf7p+vfSlsV/VCguFbyJc/ea8WNkx+N/76MmG/0=";

    meta = with pkgs.lib; {
      description = "Comically fast manga & comic optimizer for e-readers";
      homepage = "https://github.com/nicoburniske/comically";
      license = licenses.mit;
      maintainers = [ ];
    };
  };
in
{
  home.packages = [ comically ];
}
