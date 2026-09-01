{...}: {
  homeModules.lazygit = {pkgs, ...}: let
    yamlFormat = pkgs.formats.yaml {};

    openInHelix = args: "kitten @ kitten --match id:\"$KITTY_WINDOW_ID\" workspace.py open ${args}";

    mkSettings = theme: let
      colors = theme.colors.withHashtag;
    in {
      os = {
        edit = openInHelix "{{filename}}";
        editAtLine = openInHelix "{{filename}} {{line}}";
      };

      git = {
        diffRenderers = [
          {
            command = "difft --color=always --background=${theme.polarity}";
            type = "extDiff";
          }
        ];
        overrideGpg = true;
      };

      notARepository = "skip";
      promptToReturnFromSubprocess = false;

      gui = {
        sidePanelWidth = 0.25;
        theme = {
          activeBorderColor = [
            colors.base0D
            "bold"
          ];
          inactiveBorderColor = [colors.base03];
          searchingActiveBorderColor = [
            colors.base04
            "bold"
          ];
          optionsTextColor = [colors.base06];
          selectedLineBgColor = ["reverse"];
          cherryPickedCommitBgColor = [colors.base02];
          cherryPickedCommitFgColor = [colors.base03];
          unstagedChangesColor = [colors.base08];
          defaultFgColor = [colors.base05];
        };
      };
    };
  in {
    packages = [pkgs.lazygit];
    zsh.aliases.lg = "lazygit";
    file.config."lazygit/config.yml" = {
      facet = "theme";
      value = {theme}: yamlFormat.generate "seni-lazygit-${theme.variant}.yml" (mkSettings theme.value);
    };
  };
}
