theme: let
  c = theme.colors;
  mkColor = value: "#${value}";
in {
  mError = mkColor c.base08;
  mOnError = mkColor c.base00;
  mOnPrimary = mkColor c.base00;
  mOnSecondary = mkColor c.base05;
  mOnSurface = mkColor c.base05;
  mOnSurfaceVariant = mkColor c.base04;
  mOnTertiary = mkColor c.base05;
  mOnHover = mkColor c.base05;
  mOutline = mkColor c.base03;
  mPrimary = mkColor c.base0C;
  mSecondary = mkColor c.base01;
  mShadow = mkColor c.base00;
  mSurface = mkColor c.base00;
  mHover = mkColor c.base01;
  mSurfaceVariant = mkColor c.base01;
  mTertiary = mkColor c.base03;
}
