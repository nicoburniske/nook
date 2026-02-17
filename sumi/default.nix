{
  config,
  lib,
  pkgs,
  ...
}: let
  types = lib.types;
  cfg = config.sumi or {};

  selectorType = types.attrsOf (with types; either str (listOf str));

  normalizeSelector = selector:
    lib.mapAttrs (_: value:
      if builtins.isString value
      then [value]
      else value)
    selector;

  fileOptionType = types.submodule ({...}: {
    options = {
      when = lib.mkOption {
        type = selectorType;
        default = {};
        description = "Facet selector map used to conditionally include this file.";
      };

      dependsOn = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Facet keys this render function depends on. Required for render entries.";
      };

      render = lib.mkOption {
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
      when = lib.mkOption {
        type = selectorType;
        default = {};
        description = "Facet selector controlling when reload hooks should run.";
      };

      reload = lib.mkOption {
        type = with types; either str (listOf str);
        default = [];
        apply = value:
          if builtins.isString value
          then [value]
          else value;
        description = "Command or commands to run after switching selections.";
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
      file.render
      file.text
      file.source
    ]);

  selectorUnknownFacets = selector: facetNames:
    lib.filter (facet: !(builtins.elem facet facetNames)) (builtins.attrNames selector);

  selectorInvalidValues = selector: facets:
    lib.flatten
    (lib.mapAttrsToList (facet: values: let
      allowed = builtins.attrNames facets.${facet}.variants;
      invalid = lib.filter (value: !(builtins.elem value allowed)) values;
    in
      if invalid == []
      then []
      else ["${facet}: invalid values ${lib.concatStringsSep ", " invalid}"])
    selector);

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
    }

    (lib.mkIf (cfg.enable or false) (let
      resolvedHomeDirectory = cfg.homeDirectory;

      xdgSpec = {
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

      defaultSelectionUnknownFacets = selectorUnknownFacets cfg.defaultSelection facetNames;

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
          normalizedWhen = normalizeSelector fileCfg.when;
          inherit
            (fileCfg)
            render
            text
            source
            executable
            dependsOn
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
          when = normalizeSelector programCfg.when;
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

      renderMissingDependsOn =
        lib.filter (v: v != null)
        (map (file:
          if file.render != null && file.dependsOn == []
          then file.path
          else null)
        normalizedFiles);

      nonRenderWithDependsOn =
        lib.filter (v: v != null)
        (map (file:
          if file.render == null && file.dependsOn != []
          then file.path
          else null)
        normalizedFiles);

      fileSelectorFacetErrors =
        lib.filter (v: v != null)
        (map (file: let
          unknownWhen = selectorUnknownFacets file.normalizedWhen facetNames;
          unknownDependsOn = lib.filter (facet: !(builtins.elem facet facetNames)) file.dependsOn;
        in
          if unknownWhen == [] && unknownDependsOn == []
          then null
          else "${file.path}: unknown facets (${lib.concatStringsSep ", " (unknownWhen ++ unknownDependsOn)})")
        normalizedFiles);

      fileSelectorValueErrors =
        lib.filter (v: v != null)
        (map (file: let
          whenErrors =
            if selectorUnknownFacets file.normalizedWhen facetNames == []
            then selectorInvalidValues file.normalizedWhen cfg.facets
            else [];
        in
          if whenErrors == []
          then null
          else "${file.path}: ${lib.concatStringsSep "; " whenErrors}")
        normalizedFiles);

      programSelectorErrors =
        lib.filter (v: v != null)
        (map (program: let
          unknown = selectorUnknownFacets program.when facetNames;
          valueErrors =
            if unknown == []
            then selectorInvalidValues program.when cfg.facets
            else [];
        in
          if unknown == [] && valueErrors == []
          then null
          else "${program.name}: ${lib.concatStringsSep "; " ((map (f: "unknown facet ${f}") unknown) ++ valueErrors)}")
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

      renderRulesForFile = file: let
        comboSpace =
          if file.dependsOn == []
          then [{}]
          else cartesianProductOfSets (lib.genAttrs file.dependsOn (facet: facetVariantNames.${facet}));
      in
        lib.filter (rule: rule != null)
        (map (combo: let
          comboKeys = builtins.attrNames combo;
          compatible = builtins.all (facet:
            if builtins.hasAttr facet file.normalizedWhen
            then builtins.elem combo.${facet} file.normalizedWhen.${facet}
            else true)
          comboKeys;
        in
          if !compatible
          then null
          else let
            comboWhen = lib.mapAttrs (_: value: [value]) combo;
            whenRule = file.normalizedWhen // comboWhen;

            selectionBase = resolvedDefaultSelection // combo;
            selectionForRender =
              lib.foldl'
              (acc: facet: let
                allowed = whenRule.${facet};
                current = acc.${facet};
              in
                if builtins.elem current allowed
                then acc
                else acc // {${facet} = builtins.head allowed;})
              selectionBase
              (builtins.attrNames whenRule);

            ruleHash = builtins.substring 0 8 (builtins.hashString "sha256" (builtins.toJSON whenRule));

            renderedSource =
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
                rendered = file.render (mkContext selectionForRender);
              in
                if builtins.isString rendered
                then
                  pkgs.writeTextFile {
                    name = "sumi-${sanitizePath file.path}-${ruleHash}";
                    text = rendered;
                    executable = file.executable;
                  }
                else rendered;
          in {
            when = whenRule;
            source = renderedSource;
          })
        comboSpace);

      filesWithRules =
        map (file: file // {rules = renderRulesForFile file;}) normalizedFiles;

      hookRules =
        lib.flatten
        (map (program:
          map (command: {
            type = "command";
            inherit command;
            name = "${program.name}-reload";
            registration = "program-${program.name}";
            when = program.when;
          })
          program.reload)
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
              name
              type
              registration
              when
              ;
          })
          hookRules;
      };

      manifestPath = pkgs.writeText "sumi-manifest.json" (builtins.toJSON manifest);
      baseCli = pkgs.callPackage ./pkgs/sumi-cli.nix {};
      sumiLink = pkgs.callPackage ./pkgs/sumi-link.nix {};

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
          SUMI_LINK_BIN = "${sumiLink}/bin/sumi-link";
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
          message = "sumi files must set exactly one of render, text, or source: ${lib.concatStringsSep ", " invalidFiles}";
        }
        {
          assertion = renderMissingDependsOn == [];
          message = "sumi render files must set dependsOn: ${lib.concatStringsSep ", " renderMissingDependsOn}";
        }
        {
          assertion = nonRenderWithDependsOn == [];
          message = "sumi dependsOn is only valid with render: ${lib.concatStringsSep ", " nonRenderWithDependsOn}";
        }
        {
          assertion = fileSelectorFacetErrors == [];
          message = "sumi file selector facet errors: ${lib.concatStringsSep "; " fileSelectorFacetErrors}";
        }
        {
          assertion = fileSelectorValueErrors == [];
          message = "sumi file selector value errors: ${lib.concatStringsSep "; " fileSelectorValueErrors}";
        }
        {
          assertion = programSelectorErrors == [];
          message = "sumi program selector errors: ${lib.concatStringsSep "; " programSelectorErrors}";
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
