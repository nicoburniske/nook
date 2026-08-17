{
  homeModules.nushell = {
    config,
    pkgs,
    ...
  }: let
    nufmtConfig = "${config.path.config}/nufmt/nufmt.nuon";
    nufmt = pkgs.symlinkJoin {
      name = "nufmt";
      paths = [pkgs.nufmt];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/nufmt --add-flags "--config ${nufmtConfig}"
      '';
    };
  in {
    packages = [
      pkgs.nushell
      nufmt
    ];
    file.config."nufmt/nufmt.nuon" = {
      value = ''
        {
          indent: 2
        }
      '';
    };
    helix.languages = [
      {
        name = "nu";
        formatter = {
          command = "nufmt";
          args = ["--stdin"];
        };
        auto-format = true;
      }
    ];
  };
}
