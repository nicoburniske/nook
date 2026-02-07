{
  config,
  pkgs,
  inputs,
  ...
}: let
  colors = config.lib.stylix.colors;
  colorsHex = config.lib.stylix.colors.withHashtag;
  themeName = "stylix";
  diffBgStrength = 18;
  diffLineBgStrength = 24;
  rgb = name: {
    r = pkgs.lib.toInt colors."${name}-rgb-r";
    g = pkgs.lib.toInt colors."${name}-rgb-g";
    b = pkgs.lib.toInt colors."${name}-rgb-b";
  };
  hex2 = value: pkgs.lib.fixedWidthString 2 "0" (pkgs.lib.toHexString value);
  rgbToHex = value: "#${hex2 value.r}${hex2 value.g}${hex2 value.b}";
  mixChannel = a: b: percent:
    builtins.div (a * percent + b * (100 - percent)) 100;
  blendRgb = fg: bg: percent: {
    r = mixChannel fg.r bg.r percent;
    g = mixChannel fg.g bg.g percent;
    b = mixChannel fg.b bg.b percent;
  };
  blendHex = fgName: bgName: percent:
    rgbToHex (blendRgb (rgb fgName) (rgb bgName) percent);
  themeJson = builtins.toJSON {
    "$schema" = "https://opencode.ai/theme.json";
    theme = with colorsHex; {
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
      diffAddedBg = blendHex "base0B" "base00" diffBgStrength;
      diffRemovedBg = blendHex "base08" "base00" diffBgStrength;
      diffContextBg = base01;
      diffLineNumber = base03;
      diffAddedLineNumberBg = blendHex "base0B" "base00" diffLineBgStrength;
      diffRemovedLineNumberBg = blendHex "base08" "base00" diffLineBgStrength;
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
