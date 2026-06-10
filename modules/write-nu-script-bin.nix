{...}: let
  writeNuScriptBinOverlay = final: prev: {
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
            $env.PATH = (${builtins.toJSON (map (package: "${package}/bin") spec.runtimeInputs)} | append ($env.PATH? | default []))
          ''}
          ${text}
        '';
        meta.mainProgram = name;
      };
  };
  module = {
    nixpkgs.overlays = [writeNuScriptBinOverlay];
  };
in {
  flake.modules.nixos.writeNuScriptBin = module;
  flake.modules.darwin.writeNuScriptBin = module;
}
