{
  commonModules.antigravity = {pkgs, ...}: {
    nixpkgs.allowedUnfreePackages = [pkgs.antigravity-cli];
  };

  homeModules.antigravity = {
    config,
    pkgs,
    ...
  }: let
    agentPolicy = import ./instructions.nix;
    mcpServers = import ./mcp.nix;
    inherit (agentPolicy) allowedCommands forbiddenCommands;

    syncPermissions = pkgs.writers.writeNu "seni-antigravity-permissions" ''
      def main [directory: path, policy: string] {
        let settings_path = $directory | path join "settings.json"
        let settings = if ($settings_path | path exists) { open $settings_path } else { {} }
        let rules = $policy | from json
        let existing = $settings.permissions? | default {}
        let permissions = $existing | merge {
          allow: ($existing.allow? | default [] | append $rules.allow | uniq)
          deny: ($existing.deny? | default [] | append $rules.deny | uniq)
        }

        mkdir $directory
        let temporary = mktemp -p $directory
        $settings | upsert permissions $permissions | to json | save --force $temporary
        mv --force $temporary $settings_path
      }
    '';

    antigravity = pkgs.symlinkJoin {
      name = "antigravity-cli-wrapped";
      paths = [pkgs.antigravity-cli];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/agy --add-flags "--mode auto"
      '';
    };
  in {
    packages = [antigravity];
    file.home = {
      ".gemini/config/GEMINI.md".value = agentPolicy.instructions;
      ".gemini/config/mcp_config.json".value = {inherit mcpServers;} |> builtins.toJSON;
    };

    effect.antigravity-permissions.exec = [
      syncPermissions
      "${config.path.home}/.gemini/antigravity-cli"
      (builtins.toJSON {
        allow = map (command: "command(${command})") allowedCommands;
        deny = map (command: "command(${command})") forbiddenCommands;
      })
    ];
  };
}
