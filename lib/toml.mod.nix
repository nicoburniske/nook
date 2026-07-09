{lib, ...}: let
  inherit (builtins) attrNames isAttrs isBool isFloat isInt isList isPath isString match replaceStrings typeOf;

  isBareKey = key: match "[A-Za-z0-9_-]+" key != null;

  renderString = value: ''"${replaceStrings ["\\" ''"''] ["\\\\" ''\"''] (replaceStrings ["\n" "\r" "\t"] ["\\n" "\\r" "\\t"] value)}"'';

  renderKey = key:
    if isBareKey key
    then key
    else renderString key;

  renderPath = path:
    path
    |> map renderKey
    |> lib.concatStringsSep ".";

  isInlineTable = value: isAttrs value && !lib.isDerivation value && (value.__tomlInline or false);

  isScalar = value:
    isString value
    || isBool value
    || isInt value
    || isFloat value
    || isPath value
    || lib.isDerivation value
    || isInlineTable value;

  isArrayTable = value: isList value && value != [] && lib.all (item: isAttrs item && !isInlineTable item) value;

  isInlineArray = value: isList value && !isArrayTable value;

  renderInlineValue = value:
    if isString value
    then renderString value
    else if isBool value
    then lib.boolToString value
    else if isInt value || isFloat value
    then builtins.toJSON value
    else if isPath value || lib.isDerivation value
    then renderString (toString value)
    else if isInlineTable value
    then renderInlineTable value
    else if isInlineArray value
    then renderInlineArray value
    else throw "Cannot render ${typeOf value} as an inline TOML value";

  renderInlineArray = values: "[${lib.concatMapStringsSep ", " renderInlineValue values}]";

  renderInlineTable = attrs: let
    cleanAttrs = builtins.removeAttrs attrs ["__tomlInline"];
    renderPair = name: "${renderKey name} = ${renderInlineValue cleanAttrs.${name}}";
  in "{ ${lib.concatMapStringsSep ", " renderPair (attrNames cleanAttrs)} }";

  renderAssignment = name: value: "${renderKey name} = ${renderInlineValue value}";

  partitionAttrs = attrs: let
    names = attrNames attrs;
  in {
    scalarNames = lib.filter (name: isScalar attrs.${name} || isInlineArray attrs.${name}) names;
    tableNames = lib.filter (name: isAttrs attrs.${name} && !lib.isDerivation attrs.${name} && !isInlineTable attrs.${name}) names;
    arrayTableNames = lib.filter (name: isArrayTable attrs.${name}) names;
    invalidNames =
      lib.filter
      (name: !(isScalar attrs.${name} || isInlineArray attrs.${name} || isArrayTable attrs.${name} || (isAttrs attrs.${name} && !lib.isDerivation attrs.${name})))
      names;
  };

  renderTable = arrayTable: path: attrs: let
    parts = partitionAttrs attrs;
    header =
      if path == []
      then ""
      else if arrayTable
      then "[[${renderPath path}]]\n"
      else "[${renderPath path}]\n";

    assignments =
      parts.scalarNames
      |> map (name: renderAssignment name attrs.${name})
      |> lib.concatStringsSep "\n";

    tableChunks =
      parts.tableNames
      |> map (name: renderTable false (path ++ [name]) attrs.${name});

    arrayTableChunks =
      parts.arrayTableNames
      |> lib.concatMap (name: map (renderTable true (path ++ [name])) attrs.${name});

    current = header + assignments;

    rendered =
      [current]
      ++ tableChunks
      ++ arrayTableChunks
      |> lib.filter (chunk: chunk != "")
      |> lib.concatStringsSep "\n\n";
  in
    if parts.invalidNames != []
    then throw "Cannot render TOML values at ${renderPath path}: ${lib.concatStringsSep ", " parts.invalidNames}"
    else rendered;

  toml = {
    inlineTable = attrs: attrs // {__tomlInline = true;};

    toInlineTOML = attrs:
      if isAttrs attrs && !lib.isDerivation attrs
      then renderInlineTable attrs
      else throw "Inline TOML value must be an attrset";

    toTOML = attrs:
      if isAttrs attrs && !lib.isDerivation attrs
      then renderTable false [] attrs + "\n"
      else throw "TOML document must be an attrset";
  };
in {
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.anything;
    default = {};
  };

  config.flake.lib.toml = toml;
}
