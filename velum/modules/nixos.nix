{
  config,
  lib,
  pkgs,
  ...
}: let
  types = lib.types;
  velumLib = import ../lib;
  cfg = config.velum or {};

  hasStylixBase16 = lib.hasAttrByPath ["stylix" "base16"] config;

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
      base16Scheme = lib.mkOption {
        type = with types; nullOr (oneOf [path lines attrs]);
        default = null;
        description = "Base16 scheme. Accepts a path, YAML string, or attribute set.";
      };

      override = lib.mkOption {
        type = types.attrs;
        default = {};
        description = "Extra attributes merged into the base16 scheme result.";
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

      stylix = lib.mkOption {
        type = with types; nullOr attrs;
        default = null;
        description = ''
          Optional nested stylix-like shape. If set, Velum reads values from
          `themes.<name>.stylix`.
        '';
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
in {
  options.velum = {
    enable = lib.mkEnableOption "Velum theme switching runtime";

    themes = lib.mkOption {
      type = types.attrsOf themeOptionType;
      default = {};
      description = ''
        Centralized theme registry. Each theme must provide `base16Scheme`
        either directly or under `stylix`.
      '';
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
      description = "Home directory Velum should manage. If null, derived from velum.user.";
    };

    configDirectory = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Config directory Velum should target. Defaults to <homeDirectory>/.config.";
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
        Runtime state directory for Velum. If null, Velum defaults to
        `$HOME/.local/state/velum`.
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
      description = "Additional manual registrations merged with velum.programs.";
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
      description = "Host-wrapped Velum CLI package.";
    };
  };

  config = lib.mkMerge [
    {
      lib.velum =
        velumLib
        // {
          mkOutOfStoreSymlink = path: let
            pathStr = toString path;
            drvName = lib.strings.sanitizeDerivationName "velum-oos-${baseNameOf pathStr}";
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

      normalizedThemes =
        if !hasStylixBase16
        then {}
        else
          lib.mapAttrs (name: rawTheme: let
            themeSource =
              if (rawTheme ? stylix) && rawTheme.stylix != null
              then rawTheme.stylix
              else rawTheme;

            base16Scheme =
              if (themeSource ? base16Scheme) && themeSource.base16Scheme != null
              then themeSource.base16Scheme
              else throw "velum.themes.${name} must define base16Scheme (or stylix.base16Scheme)";

            override = themeSource.override or {};
            colors = (config.stylix.base16.mkSchemeAttrs base16Scheme).override override;
          in {
            inherit base16Scheme colors override;
            slug = override.slug or name;
            polarity = themeSource.polarity or "either";
            image = themeSource.image or null;
            fonts = themeSource.fonts or null;
            opacity = themeSource.opacity or null;
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
                    name = "velum-${themeName}-${sanitizePath file.path}";
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
            slug = themeContext.slug;
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

      manifestPath = pkgs.writeText "velum-manifest.json" (builtins.toJSON manifest);

      baseCli = pkgs.callPackage ../pkgs/velum-cli.nix {};

      stateDirectoryExport = lib.optionalString (cfg.stateDirectory != null) ''
        export VELUM_STATE_DIR="${cfg.stateDirectory}"
      '';

      homeDirectoryExport = lib.optionalString (resolvedHomeDirectory != null) ''
        export VELUM_HOME_DIR="${resolvedHomeDirectory}"
      '';

      configDirectoryExport = lib.optionalString (resolvedConfigDirectory != null) ''
        export VELUM_CONFIG_DIR="${resolvedConfigDirectory}"
      '';

      wrappedCli = pkgs.writeShellScriptBin "velum" ''
        export VELUM_MANIFEST="${manifestPath}"
        ${stateDirectoryExport}
        ${homeDirectoryExport}
        ${configDirectoryExport}
        exec ${baseCli}/bin/velum "$@"
      '';
    in {
      assertions = [
        {
          assertion = hasStylixBase16;
          message = ''
            Velum requires Stylix base16 helpers. Import `velum.nixosModules.default`
            so Stylix is wired automatically.
          '';
        }

        {
          assertion = cfg.themes != {};
          message = "velum.themes must define at least one theme.";
        }

        {
          assertion = cfg.defaultTheme != "";
          message = "velum.defaultTheme must be set.";
        }

        {
          assertion = resolvedHomeDirectory != null;
          message = "velum.homeDirectory or velum.user must be set when velum.enable = true.";
        }

        {
          assertion = cfg.user == null || lib.hasAttrByPath ["users" "users" cfg.user "home"] config;
          message = "velum.user must reference an existing users.users.<name>.home entry.";
        }

        {
          assertion = resolvedConfigDirectory != null;
          message = "velum.configDirectory could not be resolved.";
        }

        {
          assertion = builtins.hasAttr cfg.defaultTheme cfg.themes;
          message = "velum.defaultTheme must match a key in velum.themes.";
        }

        {
          assertion = duplicatePaths == [];
          message = "velum registrations contain duplicate file paths: ${lib.concatStringsSep ", " duplicatePaths}";
        }

        {
          assertion = absolutePaths == [];
          message = ''
            velum files must be relative to $HOME. Found absolute paths:
            ${lib.concatStringsSep ", " absolutePaths}
          '';
        }

        {
          assertion = invalidFiles == [];
          message = ''
            velum files must set exactly one of render, text, or source:
            ${lib.concatStringsSep ", " invalidFiles}
          '';
        }
      ];

      lib.velum.themeContexts = normalizedThemes;
      lib.velum.paths = {
        home = resolvedHomeDirectory;
        config = resolvedConfigDirectory;
        flakeRoot = resolvedFlakeRoot;
        flakeRootOrErr =
          if resolvedFlakeRoot != null
          then resolvedFlakeRoot
          else throw "velum.flakeRoot must be set for modules that need repository-relative paths.";
      };

      environment.etc."velum/manifest.json".source = manifestPath;
      environment.systemPackages = [wrappedCli];

      system.userActivationScripts.velum = ''
        theme="$(${wrappedCli}/bin/velum current)"
        if [ -n "$theme" ]; then
          ${wrappedCli}/bin/velum switch "$theme"
        fi
      '';

      velum.generated.manifest = manifestPath;
      velum.package = wrappedCli;
    }))
  ];
}
