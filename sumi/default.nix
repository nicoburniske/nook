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

    configDirectory = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Config directory helper path. Defaults to <homeDirectory>/.config.";
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

    file = lib.mkOption {
      type = types.attrsOf fileOptionType;
      default = {};
      description = "Managed files keyed by home-relative destination path.";
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
      resolvedHomeDirectory =
        if cfg.homeDirectory != null
        then cfg.homeDirectory
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

      normalizedFiles =
        lib.mapAttrsToList (filePath: fileCfg: {
          path = normalizeManagedPath filePath;
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
        cfg.file;

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

      absolutePaths = lib.filter (path: lib.hasPrefix "/" path) filePaths;

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
        facets =
          lib.mapAttrs (name: facet: {
            default = facet.default;
            variants = facet.variants;
          })
          cfg.facets;
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

      stateDirectoryExport = lib.optionalString (cfg.stateDirectory != null) ''
        export SUMI_STATE_DIR="${cfg.stateDirectory}"
      '';

      homeDirectoryExport = lib.optionalString (resolvedHomeDirectory != null) ''
        export SUMI_HOME_DIR="${resolvedHomeDirectory}"
      '';

      wrappedCli = pkgs.writeShellScriptBin "sumi" ''
        export SUMI_MANIFEST="${manifestPath}"
        export SUMI_LINK_BIN="${sumiLink}/bin/sumi-link"
        ${stateDirectoryExport}
        ${homeDirectoryExport}
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
          assertion = resolvedConfigDirectory != null;
          message = "sumi.configDirectory could not be resolved.";
        }
        {
          assertion = duplicatePaths == [];
          message = "sumi.file contains duplicate file paths: ${lib.concatStringsSep ", " duplicatePaths}";
        }
        {
          assertion = absolutePaths == [];
          message = "sumi files must be relative to $HOME. Found absolute paths: ${lib.concatStringsSep ", " absolutePaths}";
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
        config = resolvedConfigDirectory;
        flakeRoot = resolvedFlakeRoot;
        flakeRootOrErr =
          if resolvedFlakeRoot != null
          then resolvedFlakeRoot
          else throw "sumi.flakeRoot must be set for modules that need repository-relative paths.";
      };

      environment.etc."sumi/manifest.json".source = manifestPath;
      environment.systemPackages = [wrappedCli];

      sumi.generated.manifest = manifestPath;
      sumi.package = wrappedCli;
    }))
  ];
}
