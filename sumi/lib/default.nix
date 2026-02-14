let
  ensureConfigPath = path:
    if builtins.match "^\\.config/.*" path != null
    then path
    else ".config/${path}";

  setAttrByPath = path: value:
    if path == []
    then value
    else {
      ${builtins.head path} = setAttrByPath (builtins.tail path) value;
    };
in {
  configFile = {
    path,
    render,
    executable ? false,
  }: {
    path = ensureConfigPath path;
    inherit render executable;
  };

  file = {
    path,
    render,
    executable ? false,
  }: {
    inherit path render executable;
  };

  hook = {
    command,
    name ? "",
  }: {
    type = "command";
    inherit command name;
  };

  mkConfig = name: {
    program ? null,
    sumi,
    ...
  }:
    (
      if program == null
      then {}
      else setAttrByPath ["programs" name] program
    )
    // setAttrByPath ["sumi" "programs" name] sumi;
}
