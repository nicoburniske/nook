{...}: theme: let
  colors = theme.colors.withHashtag;
  withAlpha = color: alpha: "${color}${alpha}";

  c = with colors; {
    focusActive = base0D;
    focusInactive = base03;
    focusUrgent = base08;

    borderActive = base0D;
    borderInactive = colors.base03;

    tabActive = base0D;
    tabInactive = base03;
    tabUrgent = base08;

    insertHint = withAlpha colors.base0D "66";

    shadow = withAlpha colors.base00 "70";
    shadowInactive = withAlpha colors.base00 "4d";

    background = "transparent";
    backdrop = colors.base01;
  };

  cursorTheme =
    if theme.polarity == "light"
    then "phinger-cursors-dark"
    else "phinger-cursors-light";
in [
  {
    layout = [
      {background-color = c.background;}
      {
        focus-ring = [
          {width = 2;}
          {active-color = c.focusActive;}
          {inactive-color = c.focusInactive;}
          {urgent-color = c.focusUrgent;}
        ];
      }
      {
        border = [
          {off = {};}
          {width = 2;}
          {active-color = c.borderActive;}
          {inactive-color = c.borderInactive;}
          {urgent-color = c.focusUrgent;}
        ];
      }
      {
        shadow = [
          {on = {};}
          {softness = 24;}
          {spread = 3;}
          {
            offset.props = {
              x = 0;
              y = 5;
            };
          }
          {color = c.shadow;}
          {inactive-color = c.shadowInactive;}
        ];
      }
      {
        tab-indicator = [
          {hide-when-single-tab = {};}
          {place-within-column = {};}
          {gap = 5;}
          {width = 3;}
          {length.props.total-proportion = 1.0;}
          {position = "right";}
          {gaps-between-tabs = 2;}
          {corner-radius = 0;}
          {active-color = c.tabActive;}
          {inactive-color = c.tabInactive;}
          {urgent-color = c.tabUrgent;}
        ];
      }
      {
        insert-hint = [
          {color = c.insertHint;}
        ];
      }
    ];
  }

  {
    cursor = [
      {xcursor-theme = cursorTheme;}
      {xcursor-size = 24;}
      {hide-when-typing = {};}
      {hide-after-inactive-ms = 2500;}
    ];
  }

  {
    overview = [
      {zoom = 0.55;}
      {backdrop-color = c.backdrop;}
    ];
  }

  {
    layer-rule = [
      {match.namespace = "^launcher$";}
      {opacity = theme.opacity.popups or theme.opacity.terminal or 1.0;}
      {background-effect = [{blur = true;}];}
    ];
  }
]
