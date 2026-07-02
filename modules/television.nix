{...}: let
  televisionModule = {pkgs, ...}: {
    environment.systemPackages = [pkgs.television];

    sumi.configFile = {
      "television/cable/just.toml".value = ''
        [metadata]
        name = "just"
        description = "A channel to select recipes from Justfiles"
        requirements = [ "just",]

        [source]
        command = [ "just --summary | tr '[:blank:]' '\n'",]

        [preview]
        command = "just -s {}"

        [keybindings]
        enter = "actions:execute-recipe"

        [actions.execute-recipe]
        description = "Execute a justfile recipe"
        command = "just {}"
        mode = "execute"
      '';
    };
  };
in {
  flake.modules.nixos.television = televisionModule;
  flake.modules.darwin.television = televisionModule;
}
