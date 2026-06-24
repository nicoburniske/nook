{
  config,
  lib,
  pkgs,
  ...
}: let
  types = lib.types;
  cfg = config.sumi or {};

  fileValueType = with types; oneOf [str path package];
  fileOptionType = types.submodule ({...}: {
    options = {
      watch = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Facet keys this file reacts to. Required when value is a function.";
      };

      value = lib.mkOption {
        type = with types; nullOr (oneOf [fileValueType (functionTo fileValueType)]);
        default = null;
        description = "Static file content/source, or a function called as ctx: returning content or a source path.";
      };
    };
  });

  hookOptionType = types.submodule ({...}: {
    options = {
      watch = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Facet keys this hook reacts to.";
      };

      command = lib.mkOption {
        type = with types; nullOr (oneOf [str (functionTo str)]);
        default = null;
        description = "Shell command, or a function called as ctx: returning a shell command.";
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

  freezePathLiteral = path: let
    pathStr = toString path;
    frozenName = lib.strings.sanitizeDerivationName "sumi-frozen-${baseNameOf pathStr}";
  in
    builtins.path {
      name = frozenName;
      inherit path;
    };

  # walk nested facet payloads and freeze only path leaves before manifest serialization
  materializeManifestValue = value:
    if lib.isDerivation value
    then value
    else if builtins.isPath value
    then freezePathLiteral value
    else if builtins.isList value
    then map materializeManifestValue value
    else if builtins.isAttrs value
    then lib.mapAttrs (_: nested: materializeManifestValue nested) value
    else value;

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

    hook = lib.mkOption {
      type = types.attrsOf hookOptionType;
      default = {};
      description = "Runtime reload hooks keyed by hook name.";
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

      lib.sumi.flakePath = path: let
        pathStr = stripLeadingDotSlash path;
        errors = validateRelativePathKey pathStr;
      in
        if errors != []
        then throw "sumi flake path errors: ${lib.concatStringsSep "; " errors}"
        else "${config.lib.sumi.paths.flakeRootOrErr}/${pathStr}";

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
      resolvedFacets = materializeManifestValue cfg.facets;

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
        in
          (
            if variants == []
            then ["${facet}: variants must not be empty"]
            else []
          )
          ++ (
            if builtins.elem data.default variants
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
            value
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

      normalizedHooks =
        lib.mapAttrsToList (hookName: hookCfg: {
          name = hookName;
          watch = hookCfg.watch;
          command = hookCfg.command;
        })
        cfg.hook;

      filePaths = map (file: file.path) normalizedFiles;
      duplicatePaths =
        lib.filter
        (path: (lib.length (lib.filter (candidate: candidate == path) filePaths)) > 1)
        (lib.unique filePaths);

      filesMissingValue =
        lib.filter (v: v != null)
        (map (file:
          if file.value == null
          then file.path
          else null)
        normalizedFiles);

      functionValueMissingWatch =
        lib.filter (v: v != null)
        (map (file:
          if file.value != null && lib.isFunction file.value && file.watch == []
          then file.path
          else null)
        normalizedFiles);

      staticValueWithWatch =
        lib.filter (v: v != null)
        (map (file:
          if file.value != null && !(lib.isFunction file.value) && file.watch != []
          then file.path
          else null)
        normalizedFiles);

      hookMissingCommand =
        lib.filter (v: v != null)
        (map (hook:
          if hook.command == null
          then hook.name
          else null)
        normalizedHooks);

      hookMissingWatch =
        lib.filter (v: v != null)
        (map (hook:
          if hook.watch == []
          then hook.name
          else null)
        normalizedHooks);

      fileWatchFacetErrors =
        lib.filter (v: v != null)
        (map (file: let
          unknownWatch = lib.filter (facet: !(builtins.elem facet facetNames)) file.watch;
          duplicateWatch = lib.filter (facet: (lib.length (lib.filter (candidate: candidate == facet) file.watch)) > 1) (lib.unique file.watch);
        in
          if unknownWatch == [] && duplicateWatch == []
          then null
          else
            "${file.path}: "
            + lib.concatStringsSep "; "
            (lib.filter (msg: msg != null) [
              (
                if unknownWatch == []
                then null
                else "unknown watch facets (${lib.concatStringsSep ", " unknownWatch})"
              )
              (
                if duplicateWatch == []
                then null
                else "duplicate watch facets (${lib.concatStringsSep ", " duplicateWatch})"
              )
            ]))
        normalizedFiles);

      hookWatchFacetErrors =
        lib.filter (v: v != null)
        (map (hook: let
          unknownWatch = lib.filter (facet: !(builtins.elem facet facetNames)) hook.watch;
          duplicateWatch = lib.filter (facet: (lib.length (lib.filter (candidate: candidate == facet) hook.watch)) > 1) (lib.unique hook.watch);
        in
          if unknownWatch == [] && duplicateWatch == []
          then null
          else
            "${hook.name}: "
            + lib.concatStringsSep "; "
            (lib.filter (msg: msg != null) [
              (
                if unknownWatch == []
                then null
                else "unknown watch facets (${lib.concatStringsSep ", " unknownWatch})"
              )
              (
                if duplicateWatch == []
                then null
                else "duplicate watch facets (${lib.concatStringsSep ", " duplicateWatch})"
              )
            ]))
        normalizedHooks);

      valueLiteralErrors =
        lib.filter (v: v != null)
        (map (file:
          if file.value != null && !(lib.isFunction file.value) && builtins.isPath file.value && !(builtins.pathExists file.value)
          then "${file.path} -> ${toString file.value}"
          else null)
        normalizedFiles);

      mkFacetValues = selection:
        lib.mapAttrs (facet: variant: resolvedFacets.${facet}.variants.${variant}) selection;

      mkSelectionSubset = watch: selection:
        builtins.listToAttrs
        (map (facet: {
            name = facet;
            value = selection.${facet};
          })
          watch);

      mkWatchedContext = watch: selection: let
        watchedSelection = mkSelectionSubset watch selection;
      in {
        selection = watchedSelection;
        facets = resolvedFacets;
        values = mkFacetValues watchedSelection;
      };

      materializeFileValue = file: ruleHash: rawValue: let
        normalizedValue = materializeManifestValue rawValue;
      in
        if builtins.isString rawValue
        then
          pkgs.writeTextFile {
            name = "sumi-${sanitizePath file.path}-${ruleHash}";
            text = toString normalizedValue;
          }
        else normalizedValue;

      mkStaticFileDispatch = file: {
        kind = "static";
        value = toString (materializeFileValue file "static" file.value);
      };

      mkDynamicFileDispatch = file: let
        comboSpace = cartesianProductOfSets (lib.genAttrs file.watch (facet: facetVariantNames.${facet}));
      in {
        kind = "select";
        facets = file.watch;
        cases =
          map (combo: let
            selectionForValue = resolvedDefaultSelection // combo;
            variants = map (facet: combo.${facet}) file.watch;
            ruleHash = builtins.substring 0 8 (builtins.hashString "sha256" (builtins.toJSON variants));
            rawValue = file.value (mkWatchedContext file.watch selectionForValue);
          in {
            inherit variants;
            value = toString (materializeFileValue file ruleHash rawValue);
          })
          comboSpace;
      };

      compiledFiles =
        map (file: {
          inherit (file) path;
          dispatch =
            if lib.isFunction file.value
            then mkDynamicFileDispatch file
            else mkStaticFileDispatch file;
        })
        normalizedFiles;

      mkStaticHookDispatch = hook: {
        kind = "static";
        value = hook.command;
      };

      mkDynamicHookDispatch = hook: let
        comboSpace = cartesianProductOfSets (lib.genAttrs hook.watch (facet: facetVariantNames.${facet}));
      in {
        kind = "select";
        facets = hook.watch;
        cases =
          map (combo: let
            selectionForCommand = resolvedDefaultSelection // combo;
          in {
            variants = map (facet: combo.${facet}) hook.watch;
            value = hook.command (mkWatchedContext hook.watch selectionForCommand);
          })
          comboSpace;
      };

      compiledHooks =
        map (hook: {
          inherit
            (hook)
            name
            watch
            ;
          dispatch =
            if lib.isFunction hook.command
            then mkDynamicHookDispatch hook
            else mkStaticHookDispatch hook;
        })
        normalizedHooks;

      manifest = {
        version = 2;
        home = resolvedHomeDirectory;
        facets = resolvedFacets;
        defaultSelection = resolvedDefaultSelection;
        files = compiledFiles;
        hooks = compiledHooks;
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
          assertion = filesMissingValue == [];
          message = "sumi files must set value: ${lib.concatStringsSep ", " filesMissingValue}";
        }
        {
          assertion = functionValueMissingWatch == [];
          message = "sumi function-valued files must set watch: ${lib.concatStringsSep ", " functionValueMissingWatch}";
        }
        {
          assertion = staticValueWithWatch == [];
          message = "sumi static file values must not set watch: ${lib.concatStringsSep ", " staticValueWithWatch}";
        }
        {
          assertion = fileWatchFacetErrors == [];
          message = "sumi file watch facet errors: ${lib.concatStringsSep "; " fileWatchFacetErrors}";
        }
        {
          assertion = hookMissingCommand == [];
          message = "sumi hooks must set command: ${lib.concatStringsSep ", " hookMissingCommand}";
        }
        {
          assertion = hookMissingWatch == [];
          message = "sumi hooks must set watch: ${lib.concatStringsSep ", " hookMissingWatch}";
        }
        {
          assertion = hookWatchFacetErrors == [];
          message = "sumi hook watch facet errors: ${lib.concatStringsSep "; " hookWatchFacetErrors}";
        }
        {
          assertion = valueLiteralErrors == [];
          message = "sumi files reference missing path literals: ${lib.concatStringsSep ", " valueLiteralErrors}";
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
