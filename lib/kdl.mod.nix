# reference: https://github.com/NixOS/nixpkgs/pull/426828
{lib, ...}: let
  inherit (builtins) attrNames attrValues head isAttrs isBool isFloat isInt isList isPath isString replaceStrings typeOf;
  inherit (lib.types) attrsOf bool coercedTo listOf nullOr number oneOf path str submodule;

  renderString = value: ''"${replaceStrings ["\\" "\n" ''"''] ["\\\\" "\\n" ''\"''] value}"'';

  renderValue = raw: let
    value =
      if isAttrs raw && raw ? value
      then raw.value
      else raw;
    type =
      if isAttrs raw && raw ? type
      then raw.type
      else null;
    rendered =
      if isString value
      then renderString value
      else if isBool value
      then lib.boolToString value
      else if isInt value || isFloat value
      then builtins.toJSON value
      else if isNull value
      then "null"
      else if isPath value
      then renderString (toString value)
      else throw "Cannot render ${typeOf value} as KDL";
  in
    lib.optionalString (type != null) "(${type})" + rendered;

  indent = text:
    text
    |> lib.splitString "\n"
    |> map (line: "    " + line)
    |> lib.concatStringsSep "\n";

  isValue = value:
    isString value || isBool value || isInt value || isFloat value || isNull value || isPath value;

  isScalarAttrs = attrs:
    attrs
    |> attrValues
    |> lib.all isValue;

  attrsToChildren = attrs:
    attrs
    |> lib.mapAttrsToList (name: value: normalize {${name} = value;});

  normalize = node:
    if node ? name
    then {
      inherit (node) name;
      type = node.type or null;
      arguments = node.arguments or [];
      properties = node.properties or {};
      children = map normalize (node.children or []);
    }
    else let
      names = attrNames node;
      name = head names;
      value = node.${name};
    in
      lib.throwIfNot (isAttrs node && builtins.length names == 1) "KDL node must be a single-key attrset"
      (
        if isList value
        then {
          inherit name;
          type = null;
          arguments = [];
          properties = {};
          children = map normalize value;
        }
        else if isAttrs value
        then
          if value ? args || value ? props || value ? children
          then {
            inherit name;
            type = value.type or null;
            arguments = value.args or [];
            properties = value.props or {};
            children = map normalize (value.children or []);
          }
          else if isScalarAttrs value
          then {
            inherit name;
            type = null;
            arguments = [];
            properties = value;
            children = [];
          }
          else {
            inherit name;
            type = null;
            arguments = [];
            properties = {};
            children = attrsToChildren value;
          }
        else if isValue value
        then {
          inherit name;
          type = null;
          arguments = [value];
          properties = {};
          children = [];
        }
        else throw "Cannot render ${typeOf value} as KDL node value"
      );

  renderNode = rawNode: let
    node = normalize rawNode;
    renderedChildren =
      node.children
      |> lib.concatMapStringsSep "\n" renderNode;
    body = lib.optionalString (node.children != []) " {\n${indent renderedChildren}\n}";
    parts =
      ["${lib.optionalString (node.type != null) "(${node.type})"}${node.name}"]
      ++ map renderValue node.arguments
      ++ (node.properties |> lib.mapAttrsToList (name: value: "${name}=${renderValue value}"));
  in
    (parts |> lib.concatStringsSep " ")
    + body;

  mergeUniq = mergeOne:
    lib.mergeUniqueOption {
      message = "";
      merge = loc: defs: let
        inherit (lib.head defs) file value;
      in
        mergeOne file loc value;
    };

  mergeFlat = elemType: loc: file: value:
    if value ? _type
    then throw "${lib.showOption loc} has wrong type: expected '${elemType.description}', got `${value._type}`"
    else elemType.merge loc [{inherit file value;}];

  uniqFlatListOf = elemType:
    lib.mkOptionType {
      name = "uniqFlatListOf";
      inherit (listOf elemType) description descriptionClass;
      check = isList;
      merge = mergeUniq (
        file: loc: lib.imap1 (i: mergeFlat elemType (loc ++ ["[entry ${toString i}]"]) file)
      );
    };

  uniqFlatAttrsOf = elemType:
    lib.mkOptionType {
      name = "uniqFlatAttrsOf";
      inherit (attrsOf elemType) description descriptionClass;
      check = isAttrs;
      merge = mergeUniq (file: loc: lib.mapAttrs (name: mergeFlat elemType (loc ++ [name]) file));
    };

  kdlUntypedValue = lib.mkOptionType {
    name = "kdlUntypedValue";
    description = "KDL value without type annotation";
    descriptionClass = "noun";
    inherit (nullOr (oneOf [str bool number path])) check merge;
  };

  kdlTypedValue = lib.mkOptionType {
    name = "kdlTypedValue";
    description = "KDL value with type annotation";
    descriptionClass = "noun";
    check = isAttrs;
    merge =
      (submodule {
        options = {
          type = lib.mkOption {
            type = nullOr str;
            default = null;
          };
          value = lib.mkOption {
            type = kdlUntypedValue;
          };
        };
      }).merge;
  };

  kdlValue = lib.mkOptionType {
    name = "kdlValue";
    description = "KDL value";
    descriptionClass = "noun";
    inherit (coercedTo kdlUntypedValue (value: {inherit value;}) kdlTypedValue) check merge;
    nestedTypes = {
      type = nullOr str;
      scalar = kdlUntypedValue;
    };
  };

  kdlNode = lib.mkOptionType {
    name = "kdlNode";
    description = "KDL node";
    descriptionClass = "noun";
    check = isAttrs;
    merge =
      (submodule {
        options = {
          type = lib.mkOption {
            type = nullOr str;
            default = null;
          };
          name = lib.mkOption {
            type = str;
          };
          arguments = lib.mkOption {
            type = uniqFlatListOf kdlValue;
            default = [];
          };
          properties = lib.mkOption {
            type = uniqFlatAttrsOf kdlValue;
            default = {};
          };
          children = lib.mkOption {
            type = kdlDocument;
            default = [];
          };
        };
      }).merge;
    nestedTypes = {
      name = str;
      type = nullOr str;
      arguments = uniqFlatListOf kdlValue;
      properties = uniqFlatAttrsOf kdlValue;
      children = kdlDocument;
    };
  };

  kdlDocument = lib.mkOptionType {
    name = "kdlDocument";
    description = "KDL document";
    descriptionClass = "noun";
    check = isList;
    merge = mergeUniq (
      file: let
        mergeDocument = loc: toplevel:
          toplevel
          |> lib.imap1 (i: mergeDocumentEntry (loc ++ ["[entry ${toString i}]"]))
          |> builtins.concatLists;

        mergeDocumentEntry = loc: value: let
          inherit (lib.options) showDefs;
          defs = [{inherit file value;}];
        in
          if isList value
          then mergeDocument loc value
          else if value ? _type
          then
            if value._type == "if"
            then
              if isBool value.condition
              then
                if value.condition
                then mergeDocumentEntry loc value.content
                else []
              else throw "`mkIf` called with non-Boolean condition at ${lib.showOption loc}. Definition value:${showDefs defs}"
            else if value._type == "merge"
            then
              throw ''
                ${lib.showOption loc} has wrong type: expected a KDL node or document, got 'merge'.
                note: `mkMerge` is potentially ambiguous in a KDL document, as "merging" is application-specific. if you intended to "splat" all the nodes in a KDL document, you can just insert the list of nodes directly. you can arbitrarily nest KDL documents, and they will be concatenated.
              ''
            else throw "${lib.showOption loc} has wrong type: expected a KDL node or document, got '${value._type}'. Definition value:${showDefs defs}"
          else if kdlNode.check value
          then [(kdlNode.merge loc [{inherit file value;}])]
          else throw "${lib.showOption loc} has wrong type: expected a KDL node or document. Definition value:${showDefs defs}";
      in
        mergeDocument
    );
    nestedTypes.node = kdlNode;
  };

  kdl = {
    type = kdlDocument;
    node = name: type: arguments: properties: children: {
      inherit name type arguments properties children;
    };
    typed = type: value: {inherit type value;};
    toKDL = nodes:
      (
        if isList nodes
        then nodes
        else [nodes]
      )
      |> lib.concatMapStringsSep "\n" renderNode;
  };
in {
  flake.lib.kdl = kdl;
}
