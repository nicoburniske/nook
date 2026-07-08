{
  config,
  pkgs,
  ...
}: let
  cmdDir =
    "modules/niri/keybinds/cmd"
    |> config.lib.sumi.flakePath
    |> config.lib.sumi.mkOutOfStoreSymlink;
in
  pkgs.writeNuScriptBin "niri-cmd" {
    runtimeInputs = with pkgs; [
      ddcutil
      coreutils
      helium
      kitty
      niri
      pipewire
      pulseaudio
      procps
      systemd
      util-linux
      wlsunset
    ];
    source = ''
      def main [] {
        ^kitty ...[
          "--detach"
          "--single-instance"
          "--instance-group" "niri-cmd"
          "--class" "niri-cmd"
          "--title" "niri-cmd"
          "--override" "font_size=16"
          "--override" "tab_bar_style=hidden"
          "--override" "cursor_trail=0"
          "nu" "${cmdDir}/main.nu"
        ]

        mut id: any = null
        for line in (niri msg --json event-stream | lines) {
          let event = try { $line | from json } catch { {} }
          match $event {
            {WindowOpenedOrChanged: {window: $window}} if $id == null and $window.app_id == "niri-cmd" => {
              $id = $window.id
              niri msg action focus-window --id $id | ignore
            }
            {WindowFocusChanged: {id: $active}} | {WorkspaceActiveWindowChanged: {active_window_id: $active}} if $id != null and $active != $id => {
              niri msg action close-window --id $id | ignore
              exit 0
            }
            {WindowClosed: {id: $closed}} if $id != null and $closed == $id => {
              exit 0
            }
            _ => {}
          }
        }
      }
    '';
  }
