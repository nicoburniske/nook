{
  config,
  pkgs,
  inputs,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
  themeName = "stylix";
  themeJson = builtins.toJSON {
    "$schema" = "https://opencode.ai/theme.json";
    theme = with colors; {
      primary = base0D;
      secondary = base0E;
      accent = base0C;
      error = base08;
      warning = base0A;
      success = base0B;
      info = base0D;
      text = base05;
      textMuted = base04;
      background = base00;
      backgroundPanel = base01;
      backgroundElement = base02;
      border = base02;
      borderActive = base04;
      borderSubtle = base01;
      diffAdded = base0B;
      diffRemoved = base08;
      diffContext = base03;
      diffHunkHeader = base04;
      diffHighlightAdded = base0B;
      diffHighlightRemoved = base08;
      diffAddedBg = base01;
      diffRemovedBg = base01;
      diffContextBg = base01;
      diffLineNumber = base03;
      diffAddedLineNumberBg = base01;
      diffRemovedLineNumberBg = base01;
      markdownText = base05;
      markdownHeading = base0D;
      markdownLink = base0D;
      markdownLinkText = base0C;
      markdownCode = base0B;
      markdownBlockQuote = base03;
      markdownEmph = base09;
      markdownStrong = base0A;
      markdownHorizontalRule = base02;
      markdownListItem = base05;
      markdownListEnumeration = base0C;
      markdownImage = base0E;
      markdownImageText = base0E;
      markdownCodeBlock = base05;
      syntaxComment = base03;
      syntaxKeyword = base0E;
      syntaxFunction = base0D;
      syntaxVariable = base08;
      syntaxString = base0B;
      syntaxNumber = base09;
      syntaxType = base0A;
      syntaxOperator = base0C;
      syntaxPunctuation = base05;
    };
  };
in {
  programs.opencode = {
    enable = true;
    package = inputs.opencode.packages.${pkgs.system}.opencode;
    settings = {
      autoupdate = false;
      theme = themeName;
      tui = {
        scroll_acceleration = {
          enabled = true;
        };
      };
    };
  };

  xdg.configFile."opencode/themes/${themeName}.json".text = themeJson;
}
