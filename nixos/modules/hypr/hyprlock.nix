{lib, ...}: {
  sumi.file."hypr/hyprlock.conf" = {
    dependsOn = ["theme"];
    render = ctx: let
      theme = ctx.values.theme;
      rgb = hex: "rgb(${hex})";
      imagePath = toString theme.image;
      fontFamily = theme.fonts.serif.name;
    in
      with theme.colors; ''
        animations {
          bezier=linear, 1, 1, 0, 0
          animation=fadeIn, 1, 1.5, linear
          animation=fadeOut, 1, 1.5, linear
          animation=inputFieldDots, 1, 2, linear
          enabled=true
        }

        auth {
          pam {
            enabled=true
          }
        }

        background {
          monitor=
          blur_passes=2
          blur_size=4
          brightness=0.800000
          color=${rgb base00}
          contrast=0.900000
          noise=0.010000
          path=${imagePath}
          vibrancy=0.150000
        }

        general {
          fail_timeout=3000
          hide_cursor=true
          immediate_render=true
        }

        input-field {
          monitor=
          size=400, 70
          check_color=${rgb base0A}
          dots_center=true
          dots_size=0.200000
          dots_spacing=0.300000
          fade_on_empty=false
          fade_timeout=3000
          fail_color=${rgb base08}
          font_color=${rgb base05}
          halign=center
          hide_input=true
          inner_color=${rgb base00}
          outer_color=${rgb base03}
          outline_thickness=6
          placeholder_text=
          valign=center
        }

        label {
          monitor=
          color=${rgb base05}
          font_family=${fontFamily}
          font_size=48
          halign=center
          position=0, 150
          text=cmd[update:1000] echo "$(date +%H:%M | tr '[:upper:]' '[:lower:]')<br/><span font_size='small'>$(date '+%a %b %d' | tr '[:upper:]' '[:lower:]')</span>"
          text_align=center
          valign=center
        }
      '';
  };

  sumi.program.hyprlock.reload = [];
}
