{
  mod.common.lib = {
    nixpkgs.overlays = [
      (final: prev: {
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
