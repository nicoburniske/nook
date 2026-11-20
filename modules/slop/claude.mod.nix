{
  commonModules.claude = {pkgs, ...}: {
    nixpkgs = {
      allowedUnfreePackages = [pkgs.claude-code];
      overlays = [
        (_: prev: {
          claude-code = prev.claude-code.override {
            manifest = {
              version = "2.1.327";
              platforms =
                builtins.mapAttrs (_: checksum: {
                  binary = "claude.zst";
                  inherit checksum;
                }) {
                  darwin-arm64 = "bba95782cd2be6baa993d93fe35719eb7a168ce8cfb12b9967e84f2f31341abb";
                  darwin-x64 = "61e0618f147caa94eebfc4b3a5011c95f8ed355fc387fc7597ca58958d942567";
                  linux-arm64 = "2f2201df61973fc0637e5e50c0c81c75884bec3ca7eed856e3242ab4cfb22e17";
                  linux-x64 = "a7ba3640f5c656d697b743c20bcfa4470e8b4e88aa352be82dafe3041d5f8961";
                };
            };
          };
        })
      ];
    };
  };

  homeModules.claude = {
    lib,
    pkgs,
    ...
  }: let
    mcpServers = import ./mcp.nix;
    mcpConfig =
      {
        mcpServers =
          mcpServers
          |> lib.mapAttrs (_: {url}: {
            type = "http";
            inherit url;
          });
      }
      |> builtins.toJSON
      |> pkgs.writeText "claude-mcp-config.json";
    claude = pkgs.symlinkJoin {
      name = "claude-code-wrapped";
      paths = [pkgs.claude-code];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/claude --add-flags "--mcp-config ${mcpConfig}"
      '';
    };
  in {
    packages = [claude];
    file.home.".claude/CLAUDE.md".value = (import ./instructions.nix).instructions;
  };
}
