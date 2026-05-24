{
  inputs,
  pkgs,
}: {
  themeSwitch = import (inputs.self + "/common/theme-switch.nix") {inherit pkgs;};

  heliumProfile = pkgs.writeNuScriptBin "helium-profile" ''
    let helium = "${pkgs.helium}/bin/helium"
    let fuzzel = "${pkgs.fuzzel}/bin/fuzzel"
    let data_dir = ([$env.HOME ".config" "net.imput.helium"] | path join)
    let local_state = ([$data_dir "Local State"] | path join)

    if not ($local_state | path exists) {
      print --stderr "Helium profile data not found."
      exit 1
    }

    let state = (open --raw $local_state | from json)
    let info_cache = (($state | get -o profile.info_cache) | default {})

    let profiles = (
      $info_cache
      | transpose directory data
      | each {|row|
          let name = ($row.data.name? | default $row.directory)
          {
            name: $name,
            directory: $row.directory,
            sort_key: ($name | str downcase),
          }
        }
      | where {|row| $row.directory != "System Profile" and $row.name != "Your Helium" }
      | sort-by sort_key
      | each {|row| {name: $row.name, directory: $row.directory} }
    )

    if (($profiles | length) == 0) {
      print --stderr "No Helium profiles found."
      exit 1
    }

    let menu = ($profiles | get name | str join "\n")
    let fuzzel_result = (do { $menu | ^$fuzzel --dmenu --prompt "helium> " } | complete)

    if $fuzzel_result.exit_code != 0 {
      exit 0
    }

    let selection = ($fuzzel_result.stdout | str trim)
    if $selection == "" {
      exit 0
    }

    let directory = (($profiles | where name == $selection | get -o 0.directory) | default "")
    if $directory == "" {
      exit 0
    }

    ^$helium $"--user-data-dir=($data_dir)" $"--profile-directory=($directory)"
  '';

  windowSwitch = pkgs.writeNuScriptBin "niri-window-switch" ''
    let windows = (
      niri msg --json windows
      | from json
      | each {|window|
          let title = (
            if (($window.title? | default "") == "") { "(untitled)" } else { $window.title }
            | str replace --all "\t" " "
            | str replace --all "\n" " "
          )
          let app_id = (
            if (($window.app_id? | default "") == "") { "unknown" } else { $window.app_id }
            | str replace --all "\t" " "
            | str replace --all "\n" " "
          )
          let app = (
            if ($title | str ends-with " - YouTube - Helium") { "youtube" }
            else if ($app_id | str starts-with "chrome-open.spotify.com") { "spotify" }
            else { $app_id }
          )
          let detail = (
            if ($title | str ends-with " - YouTube - Helium") { $title | str replace --regex " - YouTube - Helium$" "" }
            else if ($title | str ends-with " - Helium") { $title | str replace --regex " - Helium$" "" }
            else { $title }
          )
          let workspace = ($window.workspace_id? | default "?")
          {
            id: $window.id,
            row: ([$window.id $"($workspace) - ($app) - ($detail)"] | str join "\t"),
            sort_key: $"($workspace)-($app)-($detail)",
          }
        }
      | sort-by sort_key
    )

    if (($windows | length) == 0) {
      exit 0
    }

    let menu = ($windows | get row | str join "\n")
    let result = (
      do {
        $menu | fuzzel --dmenu --prompt "window> " --match-mode exact --with-nth 2 --accept-nth 1 --match-nth 2 --only-match
      } | complete
    )

    if $result.exit_code != 0 {
      exit 0
    }

    let id = ($result.stdout | str trim)
    if $id == "" {
      exit 0
    }

    niri msg action focus-window --id $id | ignore
  '';

  monitorOptions = pkgs.writeNuScriptBin "niri-monitor-options" ''
    let fuzzel = "${pkgs.fuzzel}/bin/fuzzel"

    def choose [prompt: string] {
      let menu = $in
      let result = (
        do {
          $menu | ^$fuzzel --dmenu --prompt $prompt --match-mode exact --with-nth 2 --accept-nth 1 --match-nth 2 --only-match
        } | complete
      )

      if $result.exit_code != 0 {
        exit 0
      }

      let selection = ($result.stdout | str trim)
      if $selection == "" {
        exit 0
      }

      $selection
    }

    def choose_selected [prompt: string, selected: string] {
      let menu = $in
      let result = (
        do {
          $menu | ^$fuzzel --dmenu --prompt $prompt --match-mode exact --with-nth 2 --accept-nth 1 --match-nth 2 --only-match $"--select=($selected)"
        } | complete
      )

      if $result.exit_code != 0 {
        exit 0
      }

      let selection = ($result.stdout | str trim)
      if $selection == "" {
        exit 0
      }

      $selection
    }

    def active_label [label: string, active: bool] {
      if $active {
        $"* ($label)"
      } else {
        $"  ($label)"
      }
    }

    let outputs = (
      niri msg --json outputs
      | from json
      | transpose key output
      | each {|row|
          let output = $row.output
          let name = ($output.name? | default $row.key)
          let make = ($output.make? | default "")
          let model = ($output.model? | default "")
          let label = (
            if $model != "" and $make != "" {
              $"($name) - ($make) ($model)"
            } else if $model != "" {
              $"($name) - ($model)"
            } else {
              $name
            }
          )

          $output | merge {name: $name, label: $label}
        }
      | sort-by name
    )

    if (($outputs | length) == 0) {
      exit 0
    }

    let output_name = (
      if (($outputs | length) == 1) {
        $outputs | get 0.name
      } else {
        $outputs
        | each {|output| [$output.name $output.label] | str join "\t" }
        | str join "\n"
        | choose "output> "
      }
    )

    let output = ($outputs | where name == $output_name | get 0)
    let categories = (
      if ($output.vrr_supported? | default false) {
        [
          {id: "mode", label: "Mode"}
          {id: "scale", label: "Scale"}
          {id: "power", label: "Power"}
          {id: "vrr", label: "VRR"}
        ]
      } else {
        [
          {id: "mode", label: "Mode"}
          {id: "scale", label: "Scale"}
          {id: "power", label: "Power"}
        ]
      }
      | sort-by label
    )

    let category = (
      $categories
      | each {|category| [$category.id $category.label] | str join "\t" }
      | str join "\n"
      | choose $"($output_name)> "
    )

    if $category == "mode" {
      let modes = (
        $output.modes
        | each {|mode|
            let refresh_hz = ($mode.refresh_rate / 1000.0)
            let mode_value = $"($mode.width)x($mode.height)@($refresh_hz)"
            {
              value: $mode_value,
              label: $"($mode.width)x($mode.height) @ ($refresh_hz)Hz",
              pixels: ($mode.width * $mode.height),
              width: $mode.width,
              height: $mode.height,
              refresh_rate: $mode.refresh_rate,
            }
          }
        | uniq-by value
        | sort-by --reverse pixels width height refresh_rate
      )

      if (($modes | length) == 0) {
        exit 0
      }

      let current_mode_index = ($output.current_mode? | default null)
      let current_mode = (
        if $current_mode_index == null {
          null
        } else {
          $output.modes | get -o $current_mode_index | default null
        }
      )
      let current_mode_label = (
        if $current_mode == null {
          ""
        } else {
          let refresh_hz = ($current_mode.refresh_rate / 1000.0)
          active_label $"($current_mode.width)x($current_mode.height) @ ($refresh_hz)Hz" true
        }
      )

      let mode = (
        $modes
        | each {|mode| [$mode.value (active_label $mode.label ($mode.label == ($current_mode_label | str replace --regex '^\* ' "")))] | str join "\t" }
        | str join "\n"
        | choose_selected "mode> " $current_mode_label
      )

      niri msg output $output_name mode $mode | ignore
    } else if $category == "scale" {
      let current_scale = (
        $output.logical.scale?
        | default ""
        | into string
        | str replace --regex '\.0$' ""
      )
      let scale = (
        ["auto" "1" "1.25" "1.5" "1.6" "2"]
        | each {|scale| [$scale (active_label $scale ($scale == $current_scale))] | str join "\t" }
        | str join "\n"
        | choose_selected "scale> " (active_label $current_scale true)
      )

      niri msg output $output_name scale $scale | ignore
    } else if $category == "vrr" {
      let current_vrr = (
        if ($output.vrr_enabled? | default false) {
          "on"
        } else {
          "off"
        }
      )
      let vrr = (
        [
          {id: "on", label: "On"}
          {id: "on-demand", label: "On demand"}
          {id: "off", label: "Off"}
        ]
        | each {|vrr| [$vrr.id (active_label $vrr.label ($vrr.id == $current_vrr))] | str join "\t" }
        | str join "\n"
        | choose_selected "vrr> " (active_label ($current_vrr | str title-case) true)
      )

      if $vrr == "on-demand" {
        niri msg output $output_name vrr on --on-demand | ignore
      } else {
        niri msg output $output_name vrr $vrr | ignore
      }
    } else if $category == "power" {
      let power = (
        [
          {id: "on", label: "On"}
          {id: "off", label: "Off"}
        ]
        | each {|power| [$power.id (active_label $power.label ($power.id == "on"))] | str join "\t" }
        | str join "\n"
        | choose_selected "power> " (active_label "On" true)
      )

      niri msg output $output_name $power | ignore
    }
  '';
}
