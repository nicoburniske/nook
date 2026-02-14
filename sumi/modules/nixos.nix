{
  config,
  lib,
  pkgs,
  ...
}: let
  types = lib.types;
  sumiLib = import ../lib;
  cfg = config.sumi or {};

  fileOptionType = types.submodule ({...}: {
    options = {
      path = lib.mkOption {
        type = types.str;
        description = "Path to manage, relative to $HOME, e.g. .config/hypr/hyprland.conf";
      };

      render = lib.mkOption {
        type = with types; nullOr (functionTo (oneOf [str path package]));
        default = null;
        description = "Function called as theme: returns either text content or a source path/derivation.";
      };

      text = lib.mkOption {
        type = with types; nullOr lines;
        default = null;
        description = "Static text for this file.";
      };

      source = lib.mkOption {
        type = with types; nullOr (oneOf [path package str]);
        default = null;
        description = "Source path to symlink directly (file or directory).";
      };

      executable = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether generated text files should be executable.";
      };
    };
  });

  hookOptionType = types.submodule ({...}: {
    options = {
      type = lib.mkOption {
        type = types.enum ["command"];
        default = "command";
        description = "Hook type. v1 supports command hooks only.";
      };

      command = lib.mkOption {
        type = types.str;
        description = "Shell command executed after files are switched.";
      };

      name = lib.mkOption {
        type = types.str;
        default = "";
        description = "Optional hook name for debugging and introspection.";
      };
    };
  });

  registrationOptionType = types.submodule ({...}: {
    options = {
      files = lib.mkOption {
        type = types.listOf fileOptionType;
        default = [];
        description = "Managed files contributed by this registration.";
      };

      reload = lib.mkOption {
        type = types.listOf hookOptionType;
        default = [];
        description = "Hooks run after switching themes.";
      };
    };
  });

  programFileOptionType = types.submodule ({...}: {
    options = {
      render = lib.mkOption {
        type = with types; nullOr (functionTo (oneOf [str path package]));
        default = null;
        description = "Function called as theme: returns either text content or a source path/derivation.";
      };

      text = lib.mkOption {
        type = with types; nullOr lines;
        default = null;
        description = "Static text for this file.";
      };

      source = lib.mkOption {
        type = with types; nullOr (oneOf [path package str]);
        default = null;
        description = "Source path to symlink directly (file or directory).";
      };

      executable = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Whether generated text files should be executable.";
      };
    };
  });

  programOptionType = types.submodule ({...}: {
    options.reload = lib.mkOption {
      type = with types; either str (listOf str);
      default = [];
      apply = value:
        if builtins.isString value
        then [value]
        else value;
      description = "Command or commands to run after switching themes.";
    };

    freeformType = types.attrsOf programFileOptionType;
  });

  themeOptionType = types.submodule ({...}: {
    freeformType = types.attrs;

    options = {
      palette = lib.mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Color palette with base00..base0F hex values.";
      };

      meta = lib.mkOption {
        type = types.attrs;
        default = {};
        description = "Optional app-specific metadata for render functions.";
      };

      polarity = lib.mkOption {
        type = types.enum [
          "either"
          "light"
          "dark"
        ];
        default = "either";
        description = "Theme polarity metadata.";
      };

      image = lib.mkOption {
        type = with types; nullOr path;
        default = null;
        description = "Optional wallpaper metadata.";
      };

      wallpaper = lib.mkOption {
        type = with types; nullOr path;
        default = null;
        description = "Alias for image.";
      };
    };
  });

  sanitizePath = path:
    lib.replaceStrings
    [
      "/"
      "."
      " "
      ":"
      "@"
      "+"
      "\\"
    ]
    [
      "-"
      "-"
      "-"
      "-"
      "-"
      "-"
      "-"
    ]
    path;

  normalizeManagedPath = path:
    if lib.hasPrefix "/" path
    then path
    else if lib.hasPrefix "." path
    then path
    else ".config/${path}";

  fileMethodCount = file:
    lib.length
    (lib.filter (v: v != null) [
      file.render
      file.text
      file.source
    ]);

  baseKeys = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  normalizeHex = value: let
    raw = lib.strings.toLower value;
    stripped =
      if lib.hasPrefix "#" raw
      then builtins.substring 1 (builtins.stringLength raw - 1) raw
      else raw;
  in
    if builtins.match "^[0-9a-f]{6}$" stripped != null
    then stripped
    else throw "sumi theme colors must be 6-digit hex values, got '${value}'";

  normalizePalette = palette:
    lib.genAttrs baseKeys (key: normalizeHex palette.${key});
in {
  options.sumi = {
    enable = lib.mkEnableOption "Sumi theme switching runtime";

    themes = lib.mkOption {
      type = types.attrsOf themeOptionType;
      default = {};
      description = "Centralized theme registry keyed by theme name.";
    };

    defaultTheme = lib.mkOption {
      type = types.str;
      default = "";
      description = "Theme used when no state file exists yet.";
    };

    user = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Primary user name for modules that need a home directory fallback.";
    };

    homeDirectory = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Home directory Sumi should manage. If null, derived from sumi.user.";
    };

    configDirectory = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Config directory Sumi should target. Defaults to <homeDirectory>/.config.";
    };

    flakeRoot = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Flake checkout root used by app modules for source-relative assets.";
    };

    stateDirectory = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        Runtime state directory for Sumi. If null, Sumi defaults to
        `$HOME/.local/state/sumi`.
      '';
    };

    programs = lib.mkOption {
      type = types.attrsOf programOptionType;
      default = {};
      description = ''
        Program theme registrations keyed by name (for example `ghostty` or
        `hyprland`). Each program entry can contain many file entries keyed by
        destination path plus an optional `reload` command/list.
      '';
    };

    registrations = lib.mkOption {
      type = types.attrsOf registrationOptionType;
      default = {};
      description = "Additional manual registrations merged with sumi.programs.";
    };

    generated = {
      manifest = lib.mkOption {
        type = types.path;
        readOnly = true;
        internal = true;
      };
    };

    package = lib.mkOption {
      type = types.package;
      readOnly = true;
      internal = true;
      description = "Host-wrapped Sumi CLI package.";
    };
  };

  config = lib.mkMerge [
    {
      lib.sumi =
        sumiLib
        // {
          mkOutOfStoreSymlink = path: let
            pathStr = toString path;
            drvName = lib.strings.sanitizeDerivationName "sumi-oos-${baseNameOf pathStr}";
          in
            pkgs.runCommandLocal drvName {} ''
              ln -s ${lib.escapeShellArg pathStr} "$out"
            '';
        };
    }

    (lib.mkIf (cfg.enable or false) (let
      resolvedHomeDirectory =
        if cfg.homeDirectory != null
        then cfg.homeDirectory
        else if cfg.user != null && lib.hasAttrByPath ["users" "users" cfg.user "home"] config
        then config.users.users.${cfg.user}.home
        else null;

      resolvedConfigDirectory =
        if cfg.configDirectory != null
        then cfg.configDirectory
        else if resolvedHomeDirectory != null
        then "${resolvedHomeDirectory}/.config"
        else null;

      resolvedFlakeRoot =
        if cfg.flakeRoot != null
        then cfg.flakeRoot
        else null;

      themePaletteErrors =
        lib.flatten
        (lib.mapAttrsToList (name: theme: let
          palette = theme.palette or {};
          missingKeys = lib.filter (key: !(builtins.hasAttr key palette)) baseKeys;
        in
          if missingKeys == []
          then []
          else ["${name}: missing ${lib.concatStringsSep ", " missingKeys}"])
        cfg.themes);

      normalizedThemes =
        lib.mapAttrs (name: rawTheme: let
          palette = normalizePalette rawTheme.palette;
          withHashtag = lib.mapAttrs (_: value: "#${value}") palette;
        in {
          inherit name;
          colors = palette // {inherit withHashtag;};
          meta = rawTheme.meta or {};
          polarity = rawTheme.polarity or "either";
          image = rawTheme.image or rawTheme.wallpaper or null;
          fonts = rawTheme.fonts or null;
          opacity = rawTheme.opacity or null;
          raw = rawTheme;
        })
        cfg.themes;

      programRegistrations =
        lib.mapAttrs'
        (programName: programCfg: let
          fileEntries = lib.filterAttrs (key: _: key != "reload") programCfg;
        in
          lib.nameValuePair "program-${programName}" {
            files =
              lib.mapAttrsToList (filePath: fileCfg: {
                path = normalizeManagedPath filePath;
                inherit
                  (fileCfg)
                  render
                  text
                  source
                  executable
                  ;
              })
              fileEntries;

            reload =
              map (command: {
                type = "command";
                inherit command;
                name = "${programName}-reload";
              })
              programCfg.reload;
          })
        (lib.filterAttrs
          (_: programCfg: let
            fileEntries = lib.filterAttrs (key: _: key != "reload") programCfg;
          in
            (builtins.length (builtins.attrNames fileEntries)) > 0)
          cfg.programs);

      normalizedManualRegistrations =
        lib.mapAttrs
        (_: registration:
          registration
          // {
            files = builtins.map (file: file // {path = normalizeManagedPath file.path;}) registration.files;
          })
        cfg.registrations;

      allRegistrations = normalizedManualRegistrations // programRegistrations;

      invalidFiles =
        lib.filter (v: v != null)
        (lib.flatten
          (lib.mapAttrsToList (registrationName: registration:
            builtins.map
            (file:
              if fileMethodCount file == 1
              then null
              else "${registrationName}:${file.path}")
            registration.files)
          allRegistrations));

      registeredFiles =
        lib.flatten
        (lib.mapAttrsToList (registrationName: registration:
          builtins.map (file: file // {inherit registrationName;}) registration.files)
        allRegistrations);

      reloadHooks =
        lib.flatten
        (lib.mapAttrsToList (registrationName: registration:
          builtins.map (hook: hook // {inherit registrationName;}) registration.reload)
        allRegistrations);

      filePaths = builtins.map (file: file.path) registeredFiles;

      duplicatePaths =
        lib.filter
        (path: (lib.length (lib.filter (candidate: candidate == path) filePaths)) > 1)
        (lib.unique filePaths);

      absolutePaths = lib.filter (path: lib.hasPrefix "/" path) filePaths;

      renderedFilesByTheme =
        lib.mapAttrs
        (themeName: themeContext:
          builtins.map (file: {
            path = file.path;
            executable = file.executable;
            registration = file.registrationName;
            source =
              if file.source != null
              then file.source
              else let
                rendered =
                  if file.render != null
                  then file.render themeContext
                  else file.text;
              in
                if builtins.isString rendered
                then
                  pkgs.writeTextFile {
                    name = "sumi-${themeName}-${sanitizePath file.path}";
                    text = rendered;
                    executable = file.executable;
                  }
                else rendered;
          })
          registeredFiles)
        normalizedThemes;

      manifest = {
        version = 1;
        defaultTheme = cfg.defaultTheme;

        themes =
          lib.mapAttrs (themeName: themeContext: {
            name = themeContext.name;
            polarity = themeContext.polarity;
            image =
              if themeContext.image == null
              then null
              else toString themeContext.image;

            files =
              builtins.map (file: {
                inherit (file) executable path registration;
                source = toString file.source;
              })
              renderedFilesByTheme.${themeName};
          })
          normalizedThemes;

        hooks.reload =
          builtins.map (hook: {
            inherit (hook) command name type;
            registration = hook.registrationName;
          })
          reloadHooks;
      };

      manifestPath = pkgs.writeText "sumi-manifest.json" (builtins.toJSON manifest);

      baseCli = pkgs.callPackage ../pkgs/sumi-cli.nix {};

      stateDirectoryExport = lib.optionalString (cfg.stateDirectory != null) ''
        export SUMI_STATE_DIR="${cfg.stateDirectory}"
      '';

      homeDirectoryExport = lib.optionalString (resolvedHomeDirectory != null) ''
        export SUMI_HOME_DIR="${resolvedHomeDirectory}"
      '';

      configDirectoryExport = lib.optionalString (resolvedConfigDirectory != null) ''
        export SUMI_CONFIG_DIR="${resolvedConfigDirectory}"
      '';

      wrappedCli = pkgs.writeShellScriptBin "sumi" ''
        export SUMI_MANIFEST="${manifestPath}"
        ${stateDirectoryExport}
        ${homeDirectoryExport}
        ${configDirectoryExport}
        exec ${baseCli}/bin/sumi "$@"
      '';

      refreshTheme = pkgs.writeShellScript "sumi-refresh-theme" ''
        theme="$(${wrappedCli}/bin/sumi current 2>/dev/null || true)"
        if [ -z "$theme" ]; then
          theme="${cfg.defaultTheme}"
        fi
        ${wrappedCli}/bin/sumi switch "$theme" || true
      '';
    in {
      assertions = [
        {
          assertion = cfg.themes != {};
          message = "sumi.themes must define at least one theme.";
        }

        {
          assertion = cfg.defaultTheme != "";
          message = "sumi.defaultTheme must be set.";
        }

        {
          assertion = resolvedHomeDirectory != null;
          message = "sumi.homeDirectory or sumi.user must be set when sumi.enable = true.";
        }

        {
          assertion = cfg.user == null || lib.hasAttrByPath ["users" "users" cfg.user "home"] config;
          message = "sumi.user must reference an existing users.users.<name>.home entry.";
        }

        {
          assertion = resolvedConfigDirectory != null;
          message = "sumi.configDirectory could not be resolved.";
        }

        {
          assertion = builtins.hasAttr cfg.defaultTheme cfg.themes;
          message = "sumi.defaultTheme must match a key in sumi.themes.";
        }

        {
          assertion = themePaletteErrors == [];
          message = "sumi themes must include base00..base0F in palette: ${lib.concatStringsSep "; " themePaletteErrors}";
        }

        {
          assertion = duplicatePaths == [];
          message = "sumi registrations contain duplicate file paths: ${lib.concatStringsSep ", " duplicatePaths}";
        }

        {
          assertion = absolutePaths == [];
          message = ''
            sumi files must be relative to $HOME. Found absolute paths:
            ${lib.concatStringsSep ", " absolutePaths}
          '';
        }

        {
          assertion = invalidFiles == [];
          message = ''
            sumi files must set exactly one of render, text, or source:
            ${lib.concatStringsSep ", " invalidFiles}
          '';
        }
      ];

      lib.sumi.themeContexts = normalizedThemes;
      lib.sumi.paths = {
        home = resolvedHomeDirectory;
        config = resolvedConfigDirectory;
        flakeRoot = resolvedFlakeRoot;
        flakeRootOrErr =
          if resolvedFlakeRoot != null
          then resolvedFlakeRoot
          else throw "sumi.flakeRoot must be set for modules that need repository-relative paths.";
      };

      environment.etc."sumi/manifest.json".source = manifestPath;
      environment.systemPackages = [wrappedCli];

      system.userActivationScripts.sumi = ''
        ${refreshTheme}
      '';

      systemd.user.services.sumi-reapply-theme = {
        description = "Reapply current Sumi theme on session start";
        partOf = ["hyprland-session.target"];
        after = ["hyprland-session.target"];
        wantedBy = ["hyprland-session.target"];

        unitConfig = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };

        serviceConfig = {
          Type = "oneshot";
          ExecStart = refreshTheme;
        };
      };

      sumi.generated.manifest = manifestPath;
      sumi.package = wrappedCli;
    }))
  ];
}
