theme: let
  colors = theme.colors.withHashtag;
  withAlpha = color: alpha: "${color}${alpha}";
in {
  layout = {
    focusActive = colors.base0D;
    focusInactive = colors.base03;
    focusUrgent = colors.base08;

    borderActive = colors.base0D;
    borderInactive = colors.base03;

    tabActive = colors.base0D;
    tabInactive = colors.base03;
    tabUrgent = colors.base08;

    insertHint = withAlpha colors.base0D "66";

    shadow = withAlpha colors.base00 "70";
    shadowInactive = withAlpha colors.base00 "4d";

    background = "transparent";
    backdrop = colors.base01;
  };
}
