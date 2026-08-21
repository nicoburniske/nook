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
      "npm:pi-codex-fast-mode@0.2.0"
      "npm:pi-mcp-adapter@2.26.1"
      "npm:pi-web-access@0.24.0"
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

        mkdir $target
        $managed.settings.defaults
          | merge $settings
          | merge $managed.settings.enforced
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
        "/nix/store" = "allow";
        "/nix/store/*" = "allow";
        "/nix/var/nix/daemon-socket/*" = "allow";
        "/tmp/*" = "allow";
        "~/.cache/nix/*" = "allow";
        "~/.cargo/git/checkouts/*" = "allow";
        "~/.cargo/registry/*" = "allow";
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
