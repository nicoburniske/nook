{...}: let
  writeNuScriptBinOverlay = final: prev: {
    writeNuScriptBin = name: source: let
      text =
        if builtins.typeOf source == "path"
        then builtins.readFile source
        else source;
    in
      prev.writeTextFile {
        inherit name;
        executable = true;
        destination = "/bin/${name}";
        text = ''
          #!${final.nushell}/bin/nu
          ${text}
        '';
        meta.mainProgram = name;
      };
  };
in {
  flake.modules.nixos.writeNuScriptBin = {
    nixpkgs.overlays = [writeNuScriptBinOverlay];
  };

  flake.modules.darwin.writeNuScriptBin = {
    nixpkgs.overlays = [writeNuScriptBinOverlay];
  };
}
