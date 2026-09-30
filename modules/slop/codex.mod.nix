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
          ":workspace_roots" = inlineTable {".git" = "write";};
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
      version = "0.159.2";

      platformMap = {
        "aarch64-darwin" = "aarch64-apple-darwin";
        "x86_64-darwin" = "x86_64-apple-darwin";
        "x86_64-linux" = "x86_64-unknown-linux-musl";
        "aarch64-linux" = "aarch64-unknown-linux-musl";
      };

      platform = platformMap.${stdenv.hostPlatform.system};

      nativeHashes = {
        "aarch64-apple-darwin" = "sha256-Al3v/YTLyZ2I75UuWF3GfHyU5Cc/ibo9RffleZdDwTw=";
        "x86_64-apple-darwin" = "sha256-P04fcaoFsd09At1m54D3hXzxnGk0mKFx8Dj3TvPvO+k=";
        "x86_64-unknown-linux-musl" = "sha256-JlhrDSRtQaeZsO+O4a3TcPD7ByGzcJNA8o22EjgWFuo=";
        "aarch64-unknown-linux-musl" = "sha256-Ry7k1JRkpPh5K78BYr2awY1wNtvACQCgPpX3FYh+kw8=";
      };

      codeModeHostHashes = {
        "aarch64-apple-darwin" = "sha256-T588Dj6r6b7hKJRrsEzJUjQj6C+XUYgLfwPUGqnkgvI=";
        "x86_64-apple-darwin" = "sha256-z+fRcATsqqfHuQhNiXRryZ6BXuSzmhtdaGtDC2sGfME=";
        "x86_64-unknown-linux-musl" = "sha256-+2sMSnsk7Qco0SCOvABhOD2mDevG1hz2PgLEisf3Yw8=";
        "aarch64-unknown-linux-musl" = "sha256-ARlnc35e73MJY91jY24QBkCM7UPLs9bKaMXCM5mNZDA=";
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
