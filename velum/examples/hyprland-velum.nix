{config, ...}: {
  config = config.lib.velum.mkConfig "hyprland" {
    velum = {
      "hypr/hyprland.conf".render = theme:
        with theme.colors.withHashtag; ''
          # Full file render for v1.
          general {
            col.active_border = rgb(${base0D})
            col.inactive_border = rgb(${base03})
          }

          decoration {
            col.shadow = rgba(${base00}ee)
          }
        '';

      reload = "hyprctl reload";
    };
  };
}
