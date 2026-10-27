{
  homeModules.balatro = {
    config,
    pkgs,
    ...
  }: let
    cartomancer = pkgs.fetchzip {
      url = "https://github.com/stupxd/Cartomancer/releases/download/v.4.17e/Cartomancer.zip";
      hash = "sha256-8Be0cqUfJJE5iX2I9739kRPCBtZRJ9KH35GsrsbHXGs=";
    };
    jokerDisplay = pkgs.fetchzip {
      url = "https://github.com/nh6574/JokerDisplay/archive/refs/tags/v2.0.8.tar.gz";
      hash = "sha256-oEKxXf8Mj+MwVFkBfppb9h/U13SwDwM4wX7PuzKjW7g=";
    };
    lovelyArchive = pkgs.fetchurl {
      url = "https://github.com/ethangreen-dev/lovely-injector/releases/download/v0.10.0/lovely-x86_64-pc-windows-msvc.zip";
      hash = "sha256-f0gfmEq47mM8kM4YIgyIotqPk8qGtsPj/3CnJcBYB6s=";
    };
    lovely = pkgs.runCommandLocal "balatro-lovely-0.10.0.dll" {nativeBuildInputs = [pkgs.unzip];} ''
      unzip -p ${lovelyArchive} winmm.dll > "$out"
    '';
  in {
    packages = [
      (pkgs.writeScriptBin "balatro-modded" ''
        #!/bin/sh
        : "''${1:?set Balatro's Steam launch options to: balatro-modded %command%}"
        game="''${STEAM_COMPAT_INSTALL_PATH:-$PWD}"
        if [ -f "$game/Balatro.exe" ]; then
          if [ ! -e "$game/winmm.dll" ] || [ -L "$game/winmm.dll" ]; then
            /usr/bin/ln -sfT ${lovely} "$game/winmm.dll"
          else
            printf 'balatro: leaving existing %s unchanged\n' "$game/winmm.dll" >&2
          fi
          export LOVELY_MOD_DIR="Z:${config.path.data}/Balatro/Mods"
          export WINEDLLOVERRIDES="''${WINEDLLOVERRIDES:+$WINEDLLOVERRIDES;}winmm=n,b"
        fi
        exec "$@"
      '')
    ];
    file.data = {
      "Balatro/Mods/Cartomancer".value = cartomancer;
      "Balatro/Mods/JokerDisplay".value = jokerDisplay;
    };
  };
}
