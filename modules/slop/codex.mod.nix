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
      version = "0.158.0";

      platformMap = {
        "aarch64-darwin" = "aarch64-apple-darwin";
        "x86_64-darwin" = "x86_64-apple-darwin";
        "x86_64-linux" = "x86_64-unknown-linux-musl";
        "aarch64-linux" = "aarch64-unknown-linux-musl";
      };

      platform = platformMap.${stdenv.hostPlatform.system};

      nativeHashes = {
        "aarch64-apple-darwin" = "12kfiwhnf4z6993rl3lk2a8si82h7lmdqxkk02rka6ffz444l71l";
        "x86_64-apple-darwin" = "0sg036ljip899hl1y3f6fjbxsp77ids972brqx8f3jjkbza86fdv";
        "x86_64-unknown-linux-musl" = "0y2p1s1vgva7571bdhm9ffhq0f08rbcz1kh7szwwqak6wsk5m7xg";
        "aarch64-unknown-linux-musl" = "0379b6cj6zrg5ajg2ni4r7yk1ys6j68h8pd0hpvahigqbzzgmqwi";
      };

      codeModeHostHashes = {
        "aarch64-apple-darwin" = "1d2a1pbmpsjaq2912x9yw1v8jg7ahkyzmzxn0nwd5xbmv8c3jdhr";
        "x86_64-apple-darwin" = "0j0vldz8zjjhhmwqj7zf1bdnyr4ca9hh5drz7xkwn2wgh3cyr9xl";
        "x86_64-unknown-linux-musl" = "0g8ys7kdchpynyl59i5zlf2kjradszvaz588f5218dxswi5wcmal";
        "aarch64-unknown-linux-musl" = "1v0wmd2v0bq00lz21vsc2v7w2795iv8vx49m3b9d0nknhknfn6sl";
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
