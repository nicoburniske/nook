{pkgs}:
pkgs.writeNuScriptBin "theme-switch" ''
  let kitten = "${pkgs.kitty}/bin/kitten"
  let nu_bin = "${pkgs.nushell}/bin/nu"

  ^$kitten quick-access-terminal --instance-group theme-selector $nu_bin -c '
    let fzf = "${pkgs.fzf}/bin/fzf"
    let themes_result = (do { ^sumi facets theme } | complete)

    if $themes_result.exit_code != 0 {
      exit 0
    }

    let themes = ($themes_result.stdout | str trim)
    if $themes == "" {
      exit 0
    }

    let pick = (do {
      $themes | ^$fzf --prompt "Select theme: " --layout reverse --border rounded --color dark
    } | complete)

    if $pick.exit_code != 0 {
      exit 0
    }

    let theme = ($pick.stdout | str trim)
    if $theme != "" {
      ^sumi switch $"theme=($theme)"
    }
  '
''
