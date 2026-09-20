{
  homeModules.codex = {
    lib,
    pkgs,
    ...
  }: let
    agentPolicy = import ./instructions.nix;
    inherit (agentPolicy) allowedCommands forbiddenCommands;
    systemPrompt = agentPolicy.instructions;

    commandRules = [
      {
        commands = allowedCommands;
        decision = "allow";
      }
      {
        commands = forbiddenCommands;
        decision = "forbidden";
      }
    ];

    codexFlags = with lib.toml;
      [
        "developer_instructions=${builtins.toJSON systemPrompt}"
        ''model_provider="openai-http"''
        "model_providers.openai-http=${toInlineTOML {
          name = "OpenAI HTTP";
          wire_api = "responses";
          requires_openai_auth = true;
          supports_websockets = false;
          stream_idle_timeout_ms = 30000;
          stream_max_retries = 2;
        }}"
        ''default_permissions="nix"''
        ''permissions.nix.extends=":workspace"''
        "permissions.nix.filesystem=${toInlineTOML {
          "/etc/profiles" = "read";
          "/nix/store" = "read";
          "/nix/var/nix/daemon-socket" = "read";
          "~/.cache/nix" = "write";
          "~/.local/share/cargo" = "write";
        }}"
        ''permissions.nix.network.enabled=true''
        "permissions.nix.network.domains=${toInlineTOML {"*" = "allow";}}"
        "permissions.nix.network.unix_sockets=${toInlineTOML {
          "/nix/var/nix/daemon-socket/socket" = "allow";
          "/run/user/1000/gcr/ssh" = "allow";
        }}"
      ]
      |> map (value: lib.escapeShellArgs ["--config" value])
      |> lib.concatStringsSep " "
      |> lib.escapeShellArg;

    codex = pkgs.callPackage ({
      lib,
      stdenv,
      fetchurl,
      makeWrapper,
      gnutar,
      gzip,
      openssl,
      libcap,
      libz,
      bubblewrap,
    }: let
      version = "0.153.2";

      platformMap = {
        "aarch64-darwin" = "aarch64-apple-darwin";
        "x86_64-darwin" = "x86_64-apple-darwin";
        "x86_64-linux" = "x86_64-unknown-linux-musl";
        "aarch64-linux" = "aarch64-unknown-linux-musl";
      };

      platform = platformMap.${stdenv.hostPlatform.system};

      nativeHashes = {
        "aarch64-apple-darwin" = "1770x6gvgwxy0r0fd11pkvf78zpjsj8amw8lv0bfrfnzy1qc5pwi";
        "x86_64-apple-darwin" = "0ypf476fbpp8619pbrjga5d0jnlplmxq4a7yqjhmahmi4zgiaifq";
        "x86_64-unknown-linux-musl" = "17lpy3yncvpg4xfi4wk3165zq638vmri1f6a20m5swhz0xh13kg8";
        "aarch64-unknown-linux-musl" = "0ap6ljxc17ixd7g37izjl6d7syv8ynhrxyck2yi0wckhngwr71l7";
      };

      codeModeHostHashes = {
        "aarch64-apple-darwin" = "02rhahcbqph0m9pz23im1za6fdimf11x31zc9klwpys1c55faw9l";
        "x86_64-apple-darwin" = "12zi68zvih4947gc0qk5k2llx968lizag9q0vvvlbr4y4vyqf1g1";
        "x86_64-unknown-linux-musl" = "0jmy5qs2zxfpys7m1gd8fsl72slznfblc0xc2gqrfzycp43layhp";
        "aarch64-unknown-linux-musl" = "01xzpk4x22z905rmk1gf6rgrm8c2aym73gkhbyvki80rd5g4izkh";
      };

      nativeBinary = fetchurl {
        url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${platform}.tar.gz";
        sha256 = nativeHashes.${platform};
      };

      codeModeHost = fetchurl {
        url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${platform}.tar.gz";
        sha256 = codeModeHostHashes.${platform};
      };

      linuxRuntimePath = lib.makeBinPath (lib.optionals stdenv.isLinux [bubblewrap]);
    in
      stdenv.mkDerivation {
        pname = "codex";
        inherit version;

        dontUnpack = true;

        dontPatchELF = true;
        dontStrip = true;

        nativeBuildInputs = [gnutar gzip makeWrapper];
        buildInputs = lib.optionals stdenv.isLinux [openssl libcap libz];

        buildPhase = ''
          runHook preBuild
          mkdir -p build
          tar -xzf ${nativeBinary} -C build
          mv build/codex-${platform} build/codex
          chmod u+w,+x build/codex

          tar -xzf ${codeModeHost} -C build
          mv build/codex-code-mode-host-${platform} build/codex-code-mode-host
          chmod u+w,+x build/codex-code-mode-host

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin

          cp build/codex $out/bin/codex-raw
          chmod +x $out/bin/codex-raw
          cp build/codex-code-mode-host $out/bin/codex-code-mode-host
          chmod +x $out/bin/codex-code-mode-host
          makeWrapper "$out/bin/codex-raw" "$out/bin/codex" \
            --argv0 codex \
            --run 'export CODEX_EXECUTABLE_PATH="$HOME/.local/bin/codex"' \
            --set DISABLE_AUTOUPDATER 1 \
            --add-flags ${codexFlags} \
            ${lib.optionalString stdenv.isLinux ''--prefix PATH : "${linuxRuntimePath}"''}
          runHook postInstall
        '';

        meta = with lib; {
          description = "OpenAI Codex CLI (Native Binary) - AI coding assistant in your terminal";
          homepage = "https://github.com/openai/codex";
          license = licenses.asl20;
          platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
          mainProgram = "codex";
        };
      }) {};
  in {
    packages = [codex];
    file.home.".codex/rules/default.rules" = {
      value =
        commandRules
        |> lib.concatMap ({
          commands,
          decision,
        }:
          commands
          |> map (command: ''
            prefix_rule(
                pattern = ${builtins.toJSON (lib.splitString " " command)},
                decision = ${builtins.toJSON decision},
            )
          ''))
        |> lib.concatStringsSep "\n";
    };
  };
}
