{...}: let
  overlay = final: prev: {
    writeNuScriptBin = name: spec: let
      text =
        if builtins.typeOf spec.source == "path"
        then builtins.readFile spec.source
        else spec.source;
    in
      prev.writeTextFile {
        inherit name;
        executable = true;
        destination = "/bin/${name}";
        text = ''
          #!${final.nushell}/bin/nu
          ${final.lib.optionalString ((spec.runtimeInputs or []) != []) ''
            $env.PATH = (${
              spec.runtimeInputs
              |> map (package: "${package}/bin")
              |> builtins.toJSON
            } | append ($env.PATH? | default []))
          ''}
          ${text}
        '';
        meta.mainProgram = name;
      };
  };

  module = {
    nixpkgs.overlays = [overlay];
  };
in {
  flake.modules.nixos.lib = module;
  flake.modules.darwin.lib = module;
}
