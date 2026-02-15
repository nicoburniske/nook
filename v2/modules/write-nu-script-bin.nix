{...}: let
  writeNuScriptBinOverlay = final: prev: {
    writeNuScriptBin = name: text:
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
