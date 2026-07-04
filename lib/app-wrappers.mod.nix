{
  commonModules.lib = {
    nixpkgs.overlays = [
      (final: prev: {
        writeChromiumApp = {
          name,
          url,
          desktopName,
          icon ? name,
          categories ? [],
          userDataDir,
        }: let
          app = prev.runCommand name {nativeBuildInputs = [final.makeBinaryWrapper];} ''
            mkdir -p $out/bin
            makeBinaryWrapper ${final.chromium}/bin/chromium $out/bin/${name} \
              --add-flags "--user-data-dir=${userDataDir}" \
              --add-flags "--app=${url}"
          '';
          desktop = final.makeDesktopItem {
            inherit name desktopName icon categories;
            exec = "${app}/bin/${name}";
          };
        in [
          app
          desktop
        ];

        writeNuScriptBin = name: spec: let
          text =
            if builtins.typeOf spec.source == "path"
            then builtins.readFile spec.source
            else spec.source;
          path =
            (spec.runtimeInputs or [])
            |> map (package: "${final.lib.getBin package}/bin")
            |> builtins.toJSON;
        in
          prev.writeTextFile {
            inherit name;
            executable = true;
            destination = "/bin/${name}";
            text = ''
              #!${final.nushell}/bin/nu
              $env.PATH = ${path} ++ $env.PATH
              ${text}
            '';
            meta.mainProgram = name;
          };
      })
    ];
  };
}
