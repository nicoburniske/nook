{pkgs}: let
  loadThemes = ''
    let themes_result = (do { ^sumi facets theme --json } | complete)

    if $themes_result.exit_code != 0 {
      exit 0
    }

    let themes = (
      $themes_result.stdout
      | from json
      | get variants
      | str join "\n"
      | str trim
    )
    if $themes == "" {
      exit 0
    }
  '';

  applySelection = ''
    if $pick.exit_code != 0 {
      exit 0
    }

    let theme = ($pick.stdout | str trim)
    if $theme != "" {
      ^sumi switch $"theme=($theme)"
    }
  '';
in
if pkgs.stdenv.isDarwin
then
  pkgs.writeNuScriptBin "theme-switch" ''
    let kitten = "${pkgs.kitty}/bin/kitten"
    let nu_bin = "${pkgs.nushell}/bin/nu"

    ^$kitten quick-access-terminal --instance-group theme-selector $nu_bin -c '
      let fzf = "${pkgs.fzf}/bin/fzf"
      ${loadThemes}

      let pick = (do {
        $themes | ^$fzf --prompt "Select theme: " --layout reverse --border rounded --color dark
      } | complete)

      ${applySelection}
    '
  ''
else
  pkgs.writeNuScriptBin "theme-switch" ''
    let fuzzel = "${pkgs.fuzzel}/bin/fuzzel"
    ${loadThemes}

    let pick = (do {
      $themes | ^$fuzzel --dmenu --prompt "theme> "
    } | complete)

    ${applySelection}
  ''
