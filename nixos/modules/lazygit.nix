{
  lib,
  pkgs,
  ...
}: let
  yamlFormat = pkgs.formats.yaml {};

  sendToHelix = cmd:
    lib.concatStringsSep " && " [
      "kitty @ send-text --match 'state:overlay_parent' '\\x1b'"
      "kitty @ send-text --match 'state:overlay_parent' \"${cmd}\""
      "kitty @ send-text --match 'state:overlay_parent' '\\r'"
      "kitten @ close-window --match state:self"
    ];

  mkSettings = theme: let
    colors = theme.colors.withHashtag;
    pagerTheme =
      if theme.polarity == "light"
      then "--light"
      else "--dark";
  in {
    os = {
      edit = sendToHelix ":open {{filename}}";
      editAtLine = sendToHelix ":open {{filename}}:{{line}}";
    };

    git = {
      colorArg = "always";
      pagers = [
        {pager = "delta --true-color=never --paging=never --line-numbers ${pagerTheme}";}
      ];
      overrideGpg = true;
    };

    notARepository = "skip";

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
        selectedLineBgColor = [colors.base01];
        cherryPickedCommitBgColor = [colors.base02];
        cherryPickedCommitFgColor = [colors.base03];
        unstagedChangesColor = [colors.base08];
        defaultFgColor = [colors.base05];
      };
    };
  };
in {
  environment.systemPackages = [pkgs.lazygit];

  sumi.programs.lazygit = {
    "lazygit/config.yml".render = theme:
      yamlFormat.generate "sumi-lazygit-${theme.slug}.yml" (mkSettings theme);

    reload = [];
  };
}
