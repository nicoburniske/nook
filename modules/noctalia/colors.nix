theme: let
  c = theme.colors.withHashtag;
in {
  mPrimary = c.base0D;
  mOnPrimary = c.base00;
  mSecondary = c.base0E;
  mOnSecondary = c.base00;
  mTertiary = c.base0C;
  mOnTertiary = c.base00;
  mError = c.base08;
  mOnError = c.base00;
  mSurface = c.base00;
  mOnSurface = c.base05;
  mHover = c.base0C;
  mOnHover = c.base00;
  mSurfaceVariant = c.base01;
  mOnSurfaceVariant = c.base04;
  mOutline = c.base03;
  mShadow = c.base00;

  terminal = {
    background = c.base00;
    foreground = c.base05;
    cursor = c.base05;
    cursorText = c.base00;
    selectionBg = c.base02;
    selectionFg = c.base05;

    normal = {
      black = c.base00;
      red = c.base08;
      green = c.base0B;
      yellow = c.base0A;
      blue = c.base0D;
      magenta = c.base0E;
      cyan = c.base0C;
      white = c.base05;
    };

    bright = {
      black = c.base03;
      red = c.base08;
      green = c.base0B;
      yellow = c.base0A;
      blue = c.base0D;
      magenta = c.base0E;
      cyan = c.base0C;
      white = c.base07;
    };
  };
}
