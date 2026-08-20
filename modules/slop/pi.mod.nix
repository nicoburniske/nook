{
  homeModules.pi = {
    config,
    host,
    lib,
    pkgs,
    ...
  }: let
    version = "0.84.2";
    rev = "914cf1472e715297caa30db4b9535d534a9eb718";
    agentPolicy = import ./instructions.nix;
    piSource = pkgs.fetchFromGitHub {
      owner = "earendil-works";
      repo = "pi";
      inherit rev;
      hash = "sha256-d29ft9otYxdHRWYIAX8KMHPpppToX9ME5LbPb1rPcYo=";
    };

    pi = pkgs.pi-coding-agent.overrideAttrs (_: {
      inherit version;
      src = piSource;

      npmDeps = pkgs.fetchNpmDeps {
        src = piSource;
        hash = "sha256-6J5Efe+6ptCuR3VZojwYPZO8BBnnZsOQ4OAeB64uYOY=";
      };
      npmDepsHash = "sha256-6J5Efe+6ptCuR3VZojwYPZO8BBnnZsOQ4OAeB64uYOY=";

      modelData = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
        hash = "sha512-6MzsrYIYNVlE7SfpbL2yYb67Qo58p/7Q+xWG1RZvoX1P80aRCHSod2/13aFpxkow1lPO2LEh3c495J0Gwmyjig==";
      };
    });

    packages = [
      "npm:@gotgenes/pi-permission-system@26.3.1"
      "npm:pi-mcp-adapter@2.26.1"
      "npm:pi-web-access@0.24.0"
    ];

    settings = {
      defaultModel = "gpt-5.5";
      defaultProjectTrust = "ask";
      defaultProvider = "openai-codex";
      defaultThinkingLevel = "high";
      enableAnalytics = false;
      enableInstallTelemetry = false;
      lastChangelogVersion = version;
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
    mcp = {
      imports = ["codex"];
      mcpServers = {};
    };

    settingsSource = pkgs.writeText "pi-settings.json" (builtins.toJSON settings);
    mcpSource = pkgs.writeText "pi-mcp.json" (builtins.toJSON mcp);
    syncConfig = pkgs.writers.writeNu "seni-pi-config" ''
      def main [settings_target: path, settings_source: path, mcp_target: path, mcp_source: path] {
        let managed_settings = open $settings_source
        let current_settings = if ($settings_target | path exists) {
          try { open $settings_target } catch { {} }
        } else {
          {}
        }
        let merged_settings = $current_settings
          | default $managed_settings.defaultModel defaultModel
          | default $managed_settings.defaultProvider defaultProvider
          | default $managed_settings.defaultThinkingLevel defaultThinkingLevel
          | default $managed_settings.lastChangelogVersion lastChangelogVersion
          | upsert defaultProjectTrust $managed_settings.defaultProjectTrust
          | upsert enableAnalytics $managed_settings.enableAnalytics
          | upsert enableInstallTelemetry $managed_settings.enableInstallTelemetry
          | upsert npmCommand $managed_settings.npmCommand
          | upsert packages $managed_settings.packages

        let managed_mcp = open $mcp_source
        let current_mcp = if ($mcp_target | path exists) {
          try { open $mcp_target } catch { {} }
        } else {
          {}
        }
        let merged_mcp = $current_mcp
          | default $managed_mcp.imports imports
          | default $managed_mcp.mcpServers mcpServers

        mkdir ($settings_target | path dirname)
        $merged_settings | to json | save --force $settings_target
        $merged_mcp | to json | save --force $mcp_target
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
          "rm -rf *" = "ask";
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
      "${config.path.home}/.pi/agent/settings.json"
      settingsSource
      "${config.path.home}/.pi/agent/mcp.json"
      mcpSource
    ];
  };
}
