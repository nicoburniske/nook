let
  jaiOverlay = final: _prev: let
    jai = final.buildFHSEnv {
      name = "jai";
      targetPkgs = pkgs:
        with pkgs; [
          glibc
          stdenv.cc.cc.lib
          zlib
        ];
      extraBwrapArgs = [
        "--tmpfs"
        "/run"
        "--dir"
        "/run/jai"
        "--dir"
        "/run/jai/bin"
        "--ro-bind"
        "/run/jai/bin"
        "/run/jai/bin"
        "--dir"
        "/run/jai/modules"
        "--ro-bind"
        "/run/jai/modules"
        "/run/jai/modules"
      ];
      runScript = "/run/jai/bin/jai-linux";
    };
  in {
    inherit jai;

    jaiRoot = final.runCommandLocal "jai-root" {} ''
      mkdir -p "$out/share/jai/bin"
      ln -s ${jai}/bin/jai "$out/share/jai/bin/jai-linux"
      ln -s /run/jai/modules "$out/share/jai/modules"
    '';
  };
in {
  nixosModules.jai = {
    config,
    host,
    pkgs,
    ...
  }: let
    treeSitterJaiRev = "073a0c64abecb9ff10b675cea601a0df72cec326";

    jaiParser = let
      treeSitterJai = pkgs.tree-sitter.buildGrammar {
        language = "jai";
        version = "073a0c64";
        src = pkgs.fetchFromGitHub {
          owner = "constantitus";
          repo = "tree-sitter-jai";
          rev = treeSitterJaiRev;
          hash = "sha256-eOV8Xasab3iJRKcatBc2Pv5JElF0/yUCS38K1jDcauw=";
        };
      };
    in
      pkgs.runCommandLocal "tree-sitter-jai-parser" {} ''
        ln -s ${treeSitterJai}/parser "$out"
      '';
  in {
    nixpkgs.overlays = [jaiOverlay];

    environment.systemPackages = [
      pkgs.jai
    ];

    secrets."jai-linux" = {
      file = ./jai-linux.age;
      owner = host.user;
      path = "/run/jai/bin/jai-linux";
      mode = "0500";
      symlink = false;
    };

    secrets."jai-lld-linux" = {
      file = ./lld-linux.age;
      owner = host.user;
      path = "/run/jai/bin/lld-linux";
      mode = "0500";
      symlink = false;
    };

    secrets."jai-modules" = {
      file = ./modules.tar.zst.age;
      path = "/run/jai/modules.tar.zst";
      symlink = false;
    };

    systemd.services.jai-modules = {
      description = "extract jai modules";
      wantedBy = ["multi-user.target"];
      after = ["agenix-install-secrets.service"];
      restartTriggers = [./modules.tar.zst.age];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        rm -rf /run/jai/modules
        mkdir -p /run/jai
        ${pkgs.gnutar}/bin/tar -I ${pkgs.zstd}/bin/zstd \
          -xf /run/jai/modules.tar.zst \
          -C /run/jai
        chmod -R u=rwX,go=rX /run/jai/modules
      '';
    };

    helix = {
      grammars = [
        {
          name = "jai";
          source = {
            git = "https://github.com/constantitus/tree-sitter-jai";
            rev = treeSitterJaiRev;
          };
        }
      ];

      languages = [
        {
          name = "jai";
          scope = "source.jai";
          file-types = ["jai"];
          comment-token = "//";
          language-servers = ["jails"];
        }
      ];

      languageServers.jails = {
        command = "${config.lib.sumi.paths.home}/.local/bin/jails";
        args = [
          "-jai_path"
          "${pkgs.jaiRoot}/share/jai"
        ];
      };

      runtimeFiles = {
        "helix/runtime/grammars/jai.so".value = jaiParser;
        "helix/runtime/queries/jai".value = with config.lib.sumi; mkOutOfStoreSymlink (flakePath "modules/jai/queries");
      };
    };
  };
}
