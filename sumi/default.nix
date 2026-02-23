{
  config,
  lib,
  pkgs,
  ...
}: let
  types = lib.types;
  cfg = config.sumi or {};

  fileOptionType = types.submodule ({...}: {
    options = {
      watch = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Facet keys this generated file depends on. Required for generate entries.";
      };

      generate = lib.mkOption {
        type = with types; nullOr (functionTo (oneOf [str path package]));
        default = null;
        description = "Function called as ctx: returns text or a source path/derivation.";
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
    options = {
      watch = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Facet keys this reload hook depends on.";
      };

      reload = lib.mkOption {
        type = with types; oneOf [str (listOf str) (functionTo (either str (listOf str)))];
        default = [];
        description = "Command(s) or function(ctx -> command(s)) to run after switching selections.";
      };
    };
  });

  facetOptionType = types.submodule ({...}: {
    options = {
      default = lib.mkOption {
        type = types.str;
        description = "Default variant key for this facet.";
      };

      variants = lib.mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = "Payloads keyed by variant name.";
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

  stripLeadingDotSlash = path:
    if lib.hasPrefix "./" path
    then
      stripLeadingDotSlash
      (builtins.substring 2 ((builtins.stringLength path) - 2) path)
    else path;

  validateRelativePathKey = path: let
    normalized = stripLeadingDotSlash path;
    segments = lib.splitString "/" normalized;
  in
    lib.filter (err: err != null) [
      (
        if path == ""
        then "path must not be empty"
        else null
      )
      (
        if lib.hasPrefix "/" path
        then "path must be relative (absolute paths are not allowed)"
        else null
      )
      (
        if normalized == ""
        then "path must not resolve to an empty path"
        else null
      )
      (
        if builtins.elem ".." segments
        then "path must not contain '..'"
        else null
      )
      (
        if builtins.elem "" segments
        then "path must not contain empty segments"
        else null
      )
    ];

  toHomeRelative = home: absolute:
    if absolute == home
    then ""
    else if lib.hasPrefix "${home}/" absolute
    then
      builtins.substring
      ((builtins.stringLength home) + 1)
      ((builtins.stringLength absolute) - (builtins.stringLength home) - 1)
      absolute
    else null;

  mkManagedPath = rootRelative: key:
    if rootRelative == ""
    then key
    else "${rootRelative}/${key}";

  fileMethodCount = file:
    lib.length
    (lib.filter (v: v != null) [
      file.generate
      file.text
      file.source
    ]);

  cartesianProductOfSets = attrs: let
    names = builtins.attrNames attrs;

    go = remaining:
      if remaining == []
      then [{}]
      else let
        name = builtins.head remaining;
        tail = builtins.tail remaining;
        tailProduct = go tail;
      in
        lib.concatMap
        (value:
          map (partial: partial // {${name} = value;}) tailProduct)
        attrs.${name};
  in
    go names;
in {
  options.sumi = {
    enable = lib.mkEnableOption "Sumi facet-based runtime config switching";

    facets = lib.mkOption {
      type = types.attrsOf facetOptionType;
      default = {};
      description = "Facet registry keyed by facet name.";
    };

    defaultSelection = lib.mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Default selected variant per facet. Overrides facet defaults.";
    };

    homeDirectory = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Home directory Sumi should manage.";
    };

    configHome = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "XDG config home. Defaults to <homeDirectory>/.config.";
    };

    cacheHome = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "XDG cache home. Defaults to <homeDirectory>/.cache.";
    };

    dataHome = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "XDG data home. Defaults to <homeDirectory>/.local/share.";
    };

    stateHome = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "XDG state home. Defaults to <homeDirectory>/.local/state.";
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
        Runtime state directory for Sumi internals. If null, Sumi defaults to
        `<stateHome>/sumi`.
      '';
    };

    homeFile = lib.mkOption {
      type = types.attrsOf fileOptionType;
      default = {};
      description = "Managed files keyed by path relative to home directory.";
    };

    configFile = lib.mkOption {
      type = types.attrsOf fileOptionType;
      default = {};
      description = "Managed files keyed by path relative to XDG config home.";
    };

    cacheFile = lib.mkOption {
      type = types.attrsOf fileOptionType;
      default = {};
      description = "Managed files keyed by path relative to XDG cache home.";
    };

    dataFile = lib.mkOption {
      type = types.attrsOf fileOptionType;
      default = {};
      description = "Managed files keyed by path relative to XDG data home.";
    };

    stateFile = lib.mkOption {
      type = types.attrsOf fileOptionType;
      default = {};
      description = "Managed files keyed by path relative to XDG state home.";
    };

    program = lib.mkOption {
      type = types.attrsOf programOptionType;
      default = {};
      description = "Program reload orchestration keyed by program name.";
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
      lib.sumi.mkOutOfStoreSymlink = path: let
        pathStr = toString path;
        drvName = lib.strings.sanitizeDerivationName "sumi-oos-${baseNameOf pathStr}";
      in
        pkgs.runCommandLocal drvName {} ''
          ln -s ${lib.escapeShellArg pathStr} "$out"
        '';

      lib.sumi.renderBase16Mustache = {
        theme,
        template,
      }: let
        bases = [
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
        templateText =
          if builtins.isPath template
          then builtins.readFile template
          else template;
        c = theme.colors;
        hexAt = idx: builtins.substring idx 2 c.base01;
        placeholders =
          (map (base: "{{${base}-hex}}") bases)
          ++ [
            "{{base01-dec-r}}"
            "{{base01-dec-g}}"
            "{{base01-dec-b}}"
          ];
        replacements =
          (map (base: c.${base}) bases)
          ++ [
            (toString (lib.fromHexString (hexAt 0)))
            (toString (lib.fromHexString (hexAt 2)))
            (toString (lib.fromHexString (hexAt 4)))
          ];
      in
        builtins.replaceStrings placeholders replacements templateText;
    }

    (lib.mkIf (cfg.enable or false) (let
      resolvedHomeDirectory = cfg.homeDirectory;

      xdgSpec = {
        home = {
          optName = "homeDirectory";
          optValue = resolvedHomeDirectory;
          suffix = "";
          fileOptionName = "homeFile";
          files = cfg.homeFile;
        };

        config = {
          optName = "configHome";
          optValue = cfg.configHome;
          suffix = ".config";
          fileOptionName = "configFile";
          files = cfg.configFile;
        };

        cache = {
          optName = "cacheHome";
          optValue = cfg.cacheHome;
          suffix = ".cache";
          fileOptionName = "cacheFile";
          files = cfg.cacheFile;
        };

        data = {
          optName = "dataHome";
          optValue = cfg.dataHome;
          suffix = ".local/share";
          fileOptionName = "dataFile";
          files = cfg.dataFile;
        };

        state = {
          optName = "stateHome";
          optValue = cfg.stateHome;
          suffix = ".local/state";
          fileOptionName = "stateFile";
          files = cfg.stateFile;
        };
      };

      resolvedHomes = lib.genAttrs (builtins.attrNames xdgSpec) (kind: let
        spec = xdgSpec.${kind};
        abs =
          if spec.optValue != null
          then spec.optValue
          else if resolvedHomeDirectory != null
          then "${resolvedHomeDirectory}/${spec.suffix}"
          else null;
      in {
        inherit abs;
        rel =
          if resolvedHomeDirectory != null && abs != null
          then toHomeRelative resolvedHomeDirectory abs
          else null;
        inherit
          (spec)
          fileOptionName
          files
          optName
          ;
      });

      resolvedConfigHome = resolvedHomes.config.abs;
      resolvedCacheHome = resolvedHomes.cache.abs;
      resolvedDataHome = resolvedHomes.data.abs;
      resolvedStateHome = resolvedHomes.state.abs;

      resolvedSumiStateDirectory =
        if cfg.stateDirectory != null
        then cfg.stateDirectory
        else if resolvedStateHome != null
        then "${resolvedStateHome}/sumi"
        else null;

      homeContainmentErrors =
        if resolvedHomeDirectory == null
        then []
        else
          lib.filter (v: v != null)
          (
            (map (kind: let
              home = resolvedHomes.${kind};
            in
              if home.rel != null
              then null
              else "sumi.${home.optName} must be within sumi.homeDirectory")
            (builtins.attrNames xdgSpec))
            ++ [
              (
                if
                  resolvedSumiStateDirectory
                  != null
                  && toHomeRelative resolvedHomeDirectory resolvedSumiStateDirectory == null
                then "sumi.stateDirectory must be within sumi.homeDirectory"
                else null
              )
            ]
          );

      facetNames = builtins.attrNames cfg.facets;
      facetVariantNames = lib.mapAttrs (_: facet: builtins.attrNames facet.variants) cfg.facets;

      inferredDefaultSelection = lib.mapAttrs (_: facet: facet.default) cfg.facets;
      resolvedDefaultSelection = inferredDefaultSelection // cfg.defaultSelection;

      defaultSelectionUnknownFacets =
        lib.filter (facet: !(builtins.elem facet facetNames)) (builtins.attrNames cfg.defaultSelection);

      defaultSelectionInvalidValues =
        lib.filter (v: v != null)
        (lib.mapAttrsToList (facet: value:
          if !(builtins.hasAttr facet cfg.facets)
          then null
          else if builtins.elem value facetVariantNames.${facet}
          then null
          else "${facet}:${value}")
        cfg.defaultSelection);

      facetDefinitionErrors =
        lib.flatten
        (lib.mapAttrsToList (facet: data: let
          variants = facetVariantNames.${facet};
          hasDefault = builtins.elem data.default variants;
        in
          (
            if variants == []
            then ["${facet}: variants must not be empty"]
            else []
          )
          ++ (
            if hasDefault
            then []
            else ["${facet}: default '${data.default}' missing from variants"]
          ))
        cfg.facets);

      managedPathErrors =
        lib.flatten
        (lib.mapAttrsToList (_: spec:
          lib.filter (v: v != null)
          (lib.mapAttrsToList (filePath: _: let
            errors = validateRelativePathKey filePath;
          in
            if errors == []
            then null
            else "${spec.fileOptionName}.${filePath}: ${lib.concatStringsSep "; " errors}")
          spec.files))
        xdgSpec);

      mkNormalizedFiles = rootRelative: files:
        lib.mapAttrsToList (filePath: fileCfg: {
          path = mkManagedPath rootRelative (stripLeadingDotSlash filePath);
          inherit
            (fileCfg)
            generate
            text
            source
            executable
            watch
            ;
        })
        files;

      normalizedFiles =
        if homeContainmentErrors != []
        then []
        else
          lib.flatten
          (map (kind: let
            home = resolvedHomes.${kind};
          in
            mkNormalizedFiles home.rel home.files)
          (builtins.attrNames xdgSpec));

      normalizedPrograms =
        lib.mapAttrsToList (programName: programCfg: {
          name = programName;
          watch = programCfg.watch;
          reload = programCfg.reload;
        })
        cfg.program;

      invalidFiles =
        lib.filter (v: v != null)
        (map
          (file:
            if fileMethodCount file == 1
            then null
            else file.path)
          normalizedFiles);

      generateMissingWatch =
        lib.filter (v: v != null)
        (map (file:
          if file.generate != null && file.watch == []
          then file.path
          else null)
        normalizedFiles);

      nonGenerateWithWatch =
        lib.filter (v: v != null)
        (map (file:
          if file.generate == null && file.watch != []
          then file.path
          else null)
        normalizedFiles);

      fileWatchFacetErrors =
        lib.filter (v: v != null)
        (map (file: let
          unknownWatch = lib.filter (facet: !(builtins.elem facet facetNames)) file.watch;
        in
          if unknownWatch == []
          then null
          else "${file.path}: unknown watch facets (${lib.concatStringsSep ", " unknownWatch})")
        normalizedFiles);

      programWatchFacetErrors =
        lib.filter (v: v != null)
        (map (program: let
          unknownWatch = lib.filter (facet: !(builtins.elem facet facetNames)) program.watch;
        in
          if unknownWatch == []
          then null
          else "${program.name}: unknown watch facets (${lib.concatStringsSep ", " unknownWatch})")
        normalizedPrograms);

      filePaths = map (file: file.path) normalizedFiles;
      duplicatePaths =
        lib.filter
        (path: (lib.length (lib.filter (candidate: candidate == path) filePaths)) > 1)
        (lib.unique filePaths);

      mkFacetValues = selection:
        lib.mapAttrs (facet: variant: cfg.facets.${facet}.variants.${variant}) selection;

      mkContext = selection: {
        inherit selection;
        facets = cfg.facets;
        values = mkFacetValues selection;
      };

      sourceLiteralErrors =
        lib.filter (v: v != null)
        (map (file:
          if file.source != null && builtins.isPath file.source && !(builtins.pathExists file.source)
          then "${file.path} -> ${toString file.source}"
          else null)
        normalizedFiles);

      generateRulesForFile = file: let
        comboSpace =
          if file.watch == []
          then [{}]
          else cartesianProductOfSets (lib.genAttrs file.watch (facet: facetVariantNames.${facet}));
      in
        map (combo: let
          comboWhen = lib.mapAttrs (_: value: [value]) combo;
          selectionForGenerate = resolvedDefaultSelection // combo;
          ruleHash = builtins.substring 0 8 (builtins.hashString "sha256" (builtins.toJSON comboWhen));

          generatedSource =
            if file.source != null
            then file.source
            else if file.text != null
            then
              pkgs.writeTextFile {
                name = "sumi-${sanitizePath file.path}-${ruleHash}";
                text = file.text;
                executable = file.executable;
              }
            else let
              generated = file.generate (mkContext selectionForGenerate);
            in
              if builtins.isString generated
              then
                pkgs.writeTextFile {
                  name = "sumi-${sanitizePath file.path}-${ruleHash}";
                  text = generated;
                  executable = file.executable;
                }
              else generated;
        in {
          when = comboWhen;
          source = generatedSource;
        })
        comboSpace;

      filesWithRules =
        map (file: file // {rules = generateRulesForFile file;}) normalizedFiles;

      hookRules =
        lib.flatten
        (map (program: let
          comboSpace =
            if program.watch == []
            then [{}]
            else cartesianProductOfSets (lib.genAttrs program.watch (facet: facetVariantNames.${facet}));
        in
          lib.flatten
          (map (combo: let
            comboWhen = lib.mapAttrs (_: value: [value]) combo;
            selectionForReload = resolvedDefaultSelection // combo;
            reloadRaw =
              if lib.isFunction program.reload
              then program.reload (mkContext selectionForReload)
              else program.reload;
            reloadCommands =
              if builtins.isString reloadRaw
              then [reloadRaw]
              else reloadRaw;
          in
            map (command: {
              inherit command;
              registration = program.name;
              when = comboWhen;
            })
            reloadCommands)
          comboSpace))
        normalizedPrograms);

      manifest = {
        version = 1;
        home = resolvedHomeDirectory;
        facets = cfg.facets;
        defaultSelection = resolvedDefaultSelection;
        files =
          map (file: {
            inherit (file) path executable;
            rules =
              map (rule: {
                when = rule.when;
                source = toString rule.source;
              })
              file.rules;
          })
          filesWithRules;
        hooks.reload =
          map (hook: {
            inherit
              (hook)
              command
              registration
              when
              ;
          })
          hookRules;
      };

      manifestPath = pkgs.writeText "sumi-manifest.json" (builtins.toJSON manifest);
      baseCli = pkgs.callPackage ./cli/default.nix {};

      xdgEnv =
        lib.filterAttrs (_: value: value != null)
        {
          XDG_CONFIG_HOME = resolvedConfigHome;
          XDG_CACHE_HOME = resolvedCacheHome;
          XDG_DATA_HOME = resolvedDataHome;
          XDG_STATE_HOME = resolvedStateHome;
        };

      wrapperEnv =
        lib.filterAttrs (_: value: value != null)
        {
          SUMI_MANIFEST = manifestPath;
          SUMI_STATE_DIR = resolvedSumiStateDirectory;
          SUMI_HOME_DIR = resolvedHomeDirectory;
        }
        // xdgEnv;

      wrapperEnvExports =
        lib.concatMapStringsSep "\n"
        (name: "export ${name}=${lib.escapeShellArg (toString wrapperEnv.${name})}")
        (builtins.attrNames wrapperEnv);

      wrappedCli = pkgs.writeShellScriptBin "sumi" ''
        ${wrapperEnvExports}
        exec ${baseCli}/bin/sumi "$@"
      '';
    in {
      assertions = [
        {
          assertion = cfg.facets != {};
          message = "sumi.facets must define at least one facet.";
        }
        {
          assertion = facetDefinitionErrors == [];
          message = "sumi facet definitions are invalid: ${lib.concatStringsSep "; " facetDefinitionErrors}";
        }
        {
          assertion = defaultSelectionUnknownFacets == [];
          message = "sumi.defaultSelection contains unknown facets: ${lib.concatStringsSep ", " defaultSelectionUnknownFacets}";
        }
        {
          assertion = defaultSelectionInvalidValues == [];
          message = "sumi.defaultSelection contains invalid values: ${lib.concatStringsSep ", " defaultSelectionInvalidValues}";
        }
        {
          assertion = resolvedHomeDirectory != null;
          message = "sumi.homeDirectory must be set when sumi.enable = true.";
        }
        {
          assertion = homeContainmentErrors == [];
          message = "sumi XDG directories are invalid: ${lib.concatStringsSep "; " homeContainmentErrors}";
        }
        {
          assertion = managedPathErrors == [];
          message = "sumi managed path errors: ${lib.concatStringsSep "; " managedPathErrors}";
        }
        {
          assertion = duplicatePaths == [];
          message = "sumi managed files contain duplicate destination paths: ${lib.concatStringsSep ", " duplicatePaths}";
        }
        {
          assertion = invalidFiles == [];
          message = "sumi files must set exactly one of generate, text, or source: ${lib.concatStringsSep ", " invalidFiles}";
        }
        {
          assertion = generateMissingWatch == [];
          message = "sumi generate files must set watch: ${lib.concatStringsSep ", " generateMissingWatch}";
        }
        {
          assertion = nonGenerateWithWatch == [];
          message = "sumi watch is only valid with generate: ${lib.concatStringsSep ", " nonGenerateWithWatch}";
        }
        {
          assertion = fileWatchFacetErrors == [];
          message = "sumi file watch facet errors: ${lib.concatStringsSep "; " fileWatchFacetErrors}";
        }
        {
          assertion = programWatchFacetErrors == [];
          message = "sumi program watch facet errors: ${lib.concatStringsSep "; " programWatchFacetErrors}";
        }
        {
          assertion = sourceLiteralErrors == [];
          message = "sumi files reference missing path literals: ${lib.concatStringsSep ", " sourceLiteralErrors}";
        }
      ];

      lib.sumi.facets = cfg.facets;
      lib.sumi.paths = {
        home = resolvedHomeDirectory;
        config = resolvedConfigHome;
        cache = resolvedCacheHome;
        data = resolvedDataHome;
        state = resolvedStateHome;
        sumiState = resolvedSumiStateDirectory;
        flakeRoot = cfg.flakeRoot;
        flakeRootOrErr =
          if cfg.flakeRoot != null
          then cfg.flakeRoot
          else throw "sumi.flakeRoot must be set for modules that need repository-relative paths.";
      };

      environment.variables = lib.mapAttrs (_: value: lib.mkDefault value) xdgEnv;
      environment.etc."sumi/manifest.json".source = manifestPath;
      environment.systemPackages = [wrappedCli];

      sumi.generated.manifest = manifestPath;
      sumi.package = wrappedCli;
    }))
  ];
}
