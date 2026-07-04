{
  nixosModules.kde = {lib, ...}: let
    colorScheme = "Sumi";

    formatValue = value:
      if lib.isBool value
      then
        if value
        then "true"
        else "false"
      else toString value;

    formatSection = path: data: let
      header =
        path
        |> map (part: "[${part}]")
        |> lib.concatStrings;
      children =
        data
        |> lib.mapAttrsToList (name: formatLines (path ++ [name]));
      partitioned = lib.partition lib.isString children;
      directChildren = partitioned.right;
      indirectChildren = partitioned.wrong;
    in
      lib.optional (directChildren != []) header
      ++ directChildren
      ++ (indirectChildren |> lib.flatten);

    formatLines = path: data:
      if lib.isAttrs data
      then formatSection path data
      else "${lib.last path}=${formatValue data}";

    formatConfig = data:
      formatLines [] data
      |> lib.concatStringsSep "\n";

    rgb = hex:
      [
        (toString (lib.fromHexString (builtins.substring 0 2 hex)))
        (toString (lib.fromHexString (builtins.substring 2 2 hex)))
        (toString (lib.fromHexString (builtins.substring 4 2 hex)))
      ]
      |> lib.concatStringsSep ",";

    mkColors = theme:
      removeAttrs theme.colors ["withHashtag"]
      |> lib.mapAttrs (_: rgb);

    colorEffect = {
      ColorEffect = 0;
      ColorAmount = 0;
      ContrastEffect = 1;
      ContrastAmount = 0.5;
      IntensityEffect = 0;
      IntensityAmount = 0;
    };

    mkKdeColors = theme: let
      c = mkColors theme;
    in {
      BackgroundNormal = c.base00;
      BackgroundAlternate = c.base01;
      DecorationFocus = c.base0D;
      DecorationHover = c.base0D;
      ForegroundNormal = c.base05;
      ForegroundActive = c.base05;
      ForegroundInactive = c.base05;
      ForegroundLink = c.base05;
      ForegroundVisited = c.base05;
      ForegroundNegative = c.base08;
      ForegroundNeutral = c.base0D;
      ForegroundPositive = c.base0B;
    };

    mkColorScheme = theme: let
      c = mkColors theme;
      kdeColors = mkKdeColors theme;
    in {
      General = {
        ColorScheme = colorScheme;
        Name = colorScheme;
      };

      "ColorEffects:Disabled" = colorEffect;
      "ColorEffects:Inactive" = colorEffect;

      "Colors:Window" = kdeColors;
      "Colors:View" = kdeColors;
      "Colors:Button" = kdeColors;
      "Colors:Tooltip" = kdeColors;
      "Colors:Complementary" = kdeColors;
      "Colors:Selection" =
        kdeColors
        // {
          BackgroundNormal = c.base0D;
          BackgroundAlternate = c.base0D;
          ForegroundNormal = c.base00;
          ForegroundActive = c.base00;
          ForegroundInactive = c.base00;
          ForegroundLink = c.base00;
          ForegroundVisited = c.base00;
        };

      WM = {
        activeBlend = c.base0A;
        activeBackground = c.base00;
        activeForeground = c.base05;
        inactiveBlend = c.base03;
        inactiveBackground = c.base00;
        inactiveForeground = c.base05;
      };
    };

    mkFont = name: size: "${name},${toString size},-1,5,50,0,0,0,0,0";

    mkKdeGlobals = theme: let
      fonts = theme.fonts;
      applicationFont = mkFont fonts.sansSerif.name fonts.sizes.applications;
      desktopFont = mkFont fonts.sansSerif.name fonts.sizes.desktop;
    in {
      General = {
        ColorScheme = colorScheme;
        font = applicationFont;
        fixed = mkFont fonts.monospace.name fonts.sizes.terminal;
        desktopFont = desktopFont;
        menuFont = desktopFont;
        taskbarFont = desktopFont;
        toolBarFont = desktopFont;
        smallestReadableFont = desktopFont;
      };

      KDE = {
        widgetStyle = "kvantum";
      };

      UiSettings = {
        ColorScheme = colorScheme;
      };

      WM = {
        activeFont = desktopFont;
      };
    };
  in {
    sumi.configFile."kdeglobals" = {
      watch = "theme";
      value = ctx: formatConfig (mkKdeGlobals ctx.value);
    };

    sumi.dataFile."color-schemes/${colorScheme}.colors" = {
      watch = "theme";
      value = ctx: formatConfig (mkColorScheme ctx.value);
    };
  };
}
