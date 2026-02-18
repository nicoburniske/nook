{...}: let
  vlcModule = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.vlcScaled
    ];

    nixpkgs.overlays = [
      (final: prev: {
        vlcScaled = prev.symlinkJoin {
          name = "vlc-scaled";
          paths = [prev.vlc];
          nativeBuildInputs = [prev.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/vlc \
              --set QT_SCALE_FACTOR 2

            if [ -f "$out/share/applications/vlc.desktop" ]; then
              rm "$out/share/applications/vlc.desktop"
              substitute "${prev.vlc}/share/applications/vlc.desktop" "$out/share/applications/vlc.desktop" \
                --replace-fail "${prev.vlc}/bin/vlc" "$out/bin/vlc"
            fi
          '';
        };
      })
    ];
  };
in {
  flake.modules.nixos.vlc = vlcModule;
}
