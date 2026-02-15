theme: let
  rgb = color: "rgb(${color})";
  rgba = color: alpha: "rgba(${color}${alpha})";
in
  with theme.colors; {
    decorationShadowColor = rgba base00 "99";

    general = {
      activeBorder = rgb base0D;
      inactiveBorder = rgb base03;
    };

    group = {
      borderInactive = rgb base03;
      borderActive = rgb base0D;
      borderLockedActive = rgb base0C;

      groupbar = {
        textColor = rgb base05;
        active = rgb base0D;
        inactive = rgb base03;
      };
    };

    miscBackgroundColor = rgb base00;
  }
