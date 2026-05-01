{
  inputs,
  pkgs,
}: let
  themeSwitch = import (inputs.self + "/common/theme-switch.nix") {inherit pkgs;};

  heliumProfile = import (inputs.self + "/common/helium-profile.nix") {inherit pkgs;};

  windowSwitch = pkgs.writeNuScriptBin "hypr-window-switch" ''
    let clients = (
      hyprctl clients -j
      | from json
      | where mapped == true
      | where hidden == false
      | each {|client|
          let title = (
            if $client.title == "" { "(untitled)" } else { $client.title }
            | str replace --all "\t" " "
            | str replace --all "\n" " "
          )
          let class = (
            if $client.class == "" { "unknown" } else { $client.class }
            | str replace --all "\t" " "
            | str replace --all "\n" " "
          )
          let app = (
            if ($title | str ends-with " - YouTube - Helium") { "youtube" }
            else if ($class | str starts-with "chrome-open.spotify.com") { "spotify" }
            else { $class }
          )
          let detail = (
            if ($title | str ends-with " - YouTube - Helium") { $title | str replace --regex " - YouTube - Helium$" "" }
            else if ($title | str ends-with " - Helium") { $title | str replace --regex " - Helium$" "" }
            else { $title }
          )
          {
            address: $client.address,
            row: ([$client.address $"($client.workspace.name) - ($app) - ($detail)"] | str join "\t"),
            sort_key: $"($client.workspace.id)-($app)-($detail)",
          }
        }
      | sort-by sort_key
    )

    if (($clients | length) == 0) {
      exit 0
    }

    let menu = ($clients | get row | str join "\n")
    let result = (
      do {
        $menu | fuzzel --dmenu --prompt "window> " --match-mode exact --with-nth 2 --accept-nth 1 --match-nth 2 --only-match
      } | complete
    )

    if $result.exit_code != 0 {
      exit 0
    }

    let address = ($result.stdout | str trim)
    if $address == "" {
      exit 0
    }

    hyprctl dispatch focuswindow $"address:($address)" | ignore
  '';

  workspaceLayoutToggle = pkgs.writeNuScriptBin "hypr-workspace-layout-toggle" ''
    let active = (hyprctl activeworkspace -j | from json)
    let workspace = $active.id
    let currentLayout = (($active.tiledLayout? | default "") | str downcase)
    let nextLayout = if $currentLayout == "dwindle" { "scrolling" } else { "dwindle" }
    hyprctl keyword workspace $"($workspace),layout:($nextLayout)" | ignore
  '';
in {
  bind = [
    "$mod, Return, exec, kitty"
    "$mod, Q, killactive"
    "$mod, F, exec, hyprctl --batch \"dispatch layoutmsg colresize 1 ; dispatch layoutmsg togglefit ; dispatch layoutmsg fit active ; dispatch layoutmsg togglefit\""
    "$mod, G, fullscreen, 0"
    "CTRL ALT super, Q, exit"
    "CTRL $mod, L, exec, hyprlock"
    "$mod, Space, exec, fuzzel"
    "$mod, B, exec, ${heliumProfile}/bin/helium-profile"
    "$mod, O, exec, ${windowSwitch}/bin/hypr-window-switch"
    "$mod, T, exec, ${workspaceLayoutToggle}/bin/hypr-workspace-layout-toggle"
    "CTRL $mod, Space, exec, ${themeSwitch}/bin/theme-switch"
    "$mod, P, exec, hyprshot -m output -o ~/screenshots"
    "$mod SHIFT, P, exec, hyprshot -m region -o ~/screenshots"
    ",xf86monbrightnessup, exec, brightnessctl set 5%+"
    ",xf86monbrightnessdown, exec, brightnessctl set 5%-"
    "SHIFT,xf86monbrightnessup, exec, brightnessctl --device='kbd_backlight' set 5%+"
    "SHIFT,xf86monbrightnessdown, exec, brightnessctl --device='kbd_backlight' set 5%-"
    ",xf86audioraisevolume, exec, wpctl set-volume -l 1.0 @DEFAULT_SINK@ 5%+"
    ",xf86audiolowervolume, exec, wpctl set-volume -l 1.0 @DEFAULT_SINK@ 5%-"
    ",xf86audiomute, exec, wpctl set-mute @DEFAULT_SINK@ toggle"
    "$mod, H, movefocus, l"
    "$mod, L, movefocus, r"
    "$mod, K, movefocus, u"
    "$mod, J, movefocus, d"
    "$mod SHIFT, H, swapwindow, l"
    "$mod SHIFT, L, swapwindow, r"
    "$mod SHIFT, K, swapwindow, u"
    "$mod SHIFT, J, swapwindow, d"
    "$mod, S, layoutmsg, promote"
    "$mod, equal, layoutmsg, colresize +conf"
    "$mod, minus, layoutmsg, colresize -conf"
    "$mod, 1, workspace, 1"
    "$mod, 2, workspace, 2"
    "$mod, 3, workspace, 3"
    "$mod, 4, workspace, 4"
    "$mod, 5, workspace, 5"
    "$mod, 6, workspace, 6"
    "$mod, 7, workspace, 7"
    "$mod, 8, workspace, 8"
    "$mod, 9, workspace, 9"
    "$mod, 0, workspace, 10"
    "$mod SHIFT, 1, movetoworkspace, 1"
    "$mod SHIFT, 2, movetoworkspace, 2"
    "$mod SHIFT, 3, movetoworkspace, 3"
    "$mod SHIFT, 4, movetoworkspace, 4"
    "$mod SHIFT, 5, movetoworkspace, 5"
    "$mod SHIFT, 6, movetoworkspace, 6"
    "$mod SHIFT, 7, movetoworkspace, 7"
    "$mod SHIFT, 8, movetoworkspace, 8"
    "$mod SHIFT, 9, movetoworkspace, 9"
    "$mod SHIFT, 0, movetoworkspace, 10"
  ];

  bindm = [
    "$mod, mouse:272, movewindow"
    "$mod, mouse:273, resizewindow"
  ];
}
