{
  homeModules.pi = {
    config,
    host,
    lib,
    pkgs,
    ...
  }: let
    version = "1.6.0";
    npmDepsHash = "sha256-V7fRy44X50tqfFewWQ/k5UjvUt+AoMOZkTw/v0bib6o=";
    agentPolicy = import ./instructions.nix;
    piSource = pkgs.fetchFromGitHub {
      owner = "earendil-works";
      repo = "pi";
      tag = "v${version}";
      hash = "sha256-UVQnOMYikjxi7JREcxPZh/Uamy0l4rBvhawHR/MZZgo=";
    };

    pi = pkgs.pi-coding-agent.overrideAttrs (old: {
      inherit version npmDepsHash;
      src = piSource;

      npmDeps = pkgs.fetchNpmDeps {
        src = piSource;
        hash = npmDepsHash;
      };

      modelData = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
        hash = "sha512-9hL+eygFDEiFp//cydeUfmFsKmEqpmvsNPb10Y1W8+m5K9O+sx1hMStfu6nukrBD5sl6mP4RykCYBBNEgsVLfw==";
      };

      postInstall =
        ''
        local modules="$out/lib/node_modules/pi-monorepo/node_modules"
        rm "$modules/@earendil-works/pi-schema" "$modules/@earendil-works/p3" "$modules/p2"
        cp -r packages/schema "$modules/@earendil-works/pi-schema"
        ''
        + old.postInstall;
    });

    packages = [
      "npm:@gotgenes/pi-permission-system@26.3.1"
      "npm:pi-antigravity@0.14.0"
      "npm:pi-codex-fast-mode@0.2.0"
      "npm:pi-mcp-adapter@2.26.1"
      "npm:pi-web-access@0.48.0"
    ];

    configSource = pkgs.writeText "pi-config.json" (builtins.toJSON {
      settings = {
        defaults = {
          defaultModel = "gpt-5.6-sol";
          defaultProvider = "openai-codex";
          defaultThinkingLevel = "high";
          lastChangelogVersion = version;
        };
        enforced = {
          defaultProjectTrust = "ask";
          enableAnalytics = false;
          enableInstallTelemetry = false;
          npmCommand = [
            "nix"
            "shell"
            "--no-warn-dirty"
            "--inputs-from"
            host.flakeRoot
            "nixpkgs#nodejs_24"
            "-c"
            "npm"
          ];
          inherit packages;
        };
      };
      mcp = {
        imports = ["codex"];
        mcpServers = {};
      };
    });
    syncConfig = pkgs.writers.writeNu "seni-pi-config" ''
      def main [target: path, source: path] {
        let managed = open $source
        let settings_path = $target | path join "settings.json"
        let mcp_path = $target | path join "mcp.json"
        let settings = try { open $settings_path } catch { {} }
        let mcp = try { open $mcp_path } catch { {} }
        let extensions = $settings.extensions?
          | default []
          | where $it not-in ["builtin:mcp" "+builtin:mcp" "-builtin:mcp"]
          | append "-builtin:mcp"

        mkdir $target
        $managed.settings.defaults
          | merge $settings
          | merge $managed.settings.enforced
          | upsert extensions $extensions
          | to json
          | save --force $settings_path
        $managed.mcp
          | merge $mcp
          | to json
          | save --force $mcp_path
      }
    '';

    permission = {
      "*" = "allow";

      path = {
        "*" = "allow";
        "*.env" = "ask";
        "*.env.*" = "ask";
        "*.env.example" = "allow";
        "*.key" = "ask";
        "*.pem" = "ask";
        "~/.aws/*" = "deny";
        "~/.gnupg/*" = "deny";
        "~/.ssh/*" = "deny";
      };

      bash =
        {
          "*" = "allow";
          "darwin-rebuild switch *" = "ask";
          "git clean *" = "ask";
          "git push *" = "ask";
          "git reset --hard *" = "ask";
          "nixos-rebuild switch *" = "ask";
          "sudo *" = "ask";
        }
        // builtins.listToAttrs (map (command: {
            name = "${command}${lib.optionalString (!lib.hasSuffix "/" command) " "}*";
            value = {
              action = "deny";
              reason = "blocked by the shared agent policy";
            };
          })
          agentPolicy.forbiddenCommands);

      mcp = {
        "*" = "ask";
        mcp_connect = "allow";
        mcp_describe = "allow";
        mcp_list = "allow";
        mcp_search = "allow";
        mcp_status = "allow";
      };

      external_directory = {
        "*" = "ask";
        "/etc/profiles/*" = "allow";
        "/nix/store" = "allow";
        "/nix/store/*" = "allow";
        "/nix/var/nix/daemon-socket/*" = "allow";
        "/tmp/*" = "allow";
        "~/.cache/nix/*" = "allow";
        "~/.local/share/cargo/*" = "allow";
        "~/code/*" = "allow";
        "~/nook/*" = "allow";
      };
    };
  in {
    packages = [pi];

    file.home = {
      ".pi/agent/AGENTS.md".value = agentPolicy.instructions;
      ".pi/agent/extensions/pi-permission-system/config.json".value = builtins.toJSON {
        inherit permission;
      };
    };

    effect.pi-config.exec = [
      syncConfig
      "${config.path.home}/.pi/agent"
      configSource
    ];
  };
}
