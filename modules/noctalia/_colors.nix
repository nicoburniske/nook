theme: let
  c = theme.colors.withHashtag;
in {
  mError = c.base08;
  mOnError = c.base00;
  mOnPrimary = c.base00;
  mOnSecondary = c.base05;
  mOnSurface = c.base05;
  mOnSurfaceVariant = c.base04;
  mOnTertiary = c.base05;
  mOnHover = c.base05;
  mOutline = c.base03;
  mPrimary = c.base0C;
  mSecondary = c.base01;
  mShadow = c.base00;
  mSurface = c.base00;
  mHover = c.base01;
  mSurfaceVariant = c.base01;
  mTertiary = c.base03;

  terminal = {
    background = c.base00;
    foreground = c.base05;
    cursor = c.base05;
    cursorText = c.base00;
    selectionBg = c.base05;
    selectionFg = c.base00;

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
