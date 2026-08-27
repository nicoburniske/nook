{
  homeModules.codex = {
    lib,
    pkgs,
    ...
  }: let
    agentPolicy = import ./instructions.nix;
    inherit (agentPolicy) forbiddenCommands;
    systemPrompt = agentPolicy.instructions;

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
        "permissions.nix.network.unix_sockets=${toInlineTOML {"/nix/var/nix/daemon-socket/socket" = "allow";}}"
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
      version = "0.150.0";

      platformMap = {
        "aarch64-darwin" = "aarch64-apple-darwin";
        "x86_64-darwin" = "x86_64-apple-darwin";
        "x86_64-linux" = "x86_64-unknown-linux-musl";
        "aarch64-linux" = "aarch64-unknown-linux-musl";
      };

      platform = platformMap.${stdenv.hostPlatform.system};

      nativeHashes = {
        "aarch64-apple-darwin" = "120m36hq6wd7bm20jwv7asnklhxxldji07v7z0gdg7k5r8788abd";
        "x86_64-apple-darwin" = "0mg48b8gr9mlbrka701bf94q90ss59d6yyf154ifsgzjhffpskbg";
        "x86_64-unknown-linux-musl" = "1ckgcxcxb0b37gwqzbjk5dvmd959g059ssa3jw02mr0ffh54172y";
        "aarch64-unknown-linux-musl" = "0cl4j14q6nq73q61hza0pnr2f05j5ydp6vxs98llwgf3hqb2ddqf";
      };

      codeModeHostHashes = {
        "aarch64-apple-darwin" = "0pskvvkrdnq030815amm1j6gbw6m7464ggyh9cgakazzl40xyvxa";
        "x86_64-apple-darwin" = "012pgq3nkh0c6hpji0wyppgvp9w21hglcj6fv8jsy7m1fxcgc9cg";
        "x86_64-unknown-linux-musl" = "085r0hqx9s28729yakakdyj5vqw32isfx793jlp0q1xw66gsvyvi";
        "aarch64-unknown-linux-musl" = "12cqv0pcdjh61v1xs99wycx0949zfyrxxblwxlxq8s8r3whb40i0";
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
        forbiddenCommands
        |> map (command: ''
          prefix_rule(
              pattern = ${builtins.toJSON (lib.splitString " " command)},
              decision = "forbidden",
          )
        '')
        |> lib.concatStringsSep "\n";
    };
  };
}
