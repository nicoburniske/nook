theme:
with theme.colors.withHashtag; ''
  # Stylix-derived font and opacity
  font_family ${theme.fonts.monospace.name}
  font_size ${toString theme.fonts.sizes.terminal}
  background_opacity ${toString theme.opacity.terminal}

  # The basic colors
  background ${base00}
  foreground ${base05}
  selection_background ${base03}
  selection_foreground ${base05}

  # Cursor colors
  cursor ${base05}
  cursor_text_color ${base00}

  # URL underline color when hovering with mouse
  url_color ${base04}

  # Kitty window border colors
  active_border_color ${base03}
  inactive_border_color ${base01}

  # OS Window titlebar colors
  wayland_titlebar_color ${base00}
  macos_titlebar_color ${base00}

  # Tab bar colors
  active_tab_background ${base00}
  active_tab_foreground ${base05}
  inactive_tab_background ${base01}
  inactive_tab_foreground ${base04}
  tab_bar_background ${base01}

  # The 16 terminal colors
  color0 ${base00}
  color1 ${base08}
  color2 ${base0B}
  color3 ${base0A}
  color4 ${base0D}
  color5 ${base0E}
  color6 ${base0C}
  color7 ${base05}

  color8 ${base02}
  color9 ${base08}
  color10 ${base0B}
  color11 ${base0A}
  color12 ${base0D}
  color13 ${base0E}
  color14 ${base0C}
  color15 ${base07}

  # Extended base16 colors
  color16 ${base09}
  color17 ${base0F}
  color18 ${base01}
  color19 ${base02}
  color20 ${base04}
  color21 ${base06}

  # Custom tab overrides
  active_tab_background ${base0C}
  active_tab_foreground ${base00}

  inactive_tab_background ${base02}
  inactive_tab_foreground ${base05}

  tab_bar_margin_color ${base02}
''
