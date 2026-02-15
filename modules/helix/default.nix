{...}: let
  mkHelixModule = {pkgs}: let
    tomlFormat = pkgs.formats.toml {};

    clipboard =
      if pkgs.stdenv.isDarwin
      then "/usr/bin/pbcopy"
      else "${pkgs.wl-clipboard}/bin/wl-copy";

    copyLineRef = pkgs.writeNuScriptBin "hx-copy-line-reference" ''
      def main [buffer_name: string, cursor_line: string, selection_line_start: string, selection_line_end: string] {
        let output = if $selection_line_start != $selection_line_end {
          $"($buffer_name):($selection_line_start)-($selection_line_end)"
        } else {
          $"($buffer_name):($cursor_line)"
        }

        $output | ^${clipboard}
      }
    '';

    copyLineUrl = pkgs.writeNuScriptBin "hx-copy-line-url" ''
      def main [buffer_name: string, cursor_line: string, selection_line_start: string, selection_line_end: string] {
        let remote_result = (do { ^git remote get-url origin } | complete)
        if $remote_result.exit_code != 0 {
          exit 1
        }

        let raw_url = ($remote_result.stdout | str trim)
        if $raw_url == "" {
          exit 1
        }

        let repo_url = if ($raw_url | str starts-with "git@") {
          let no_prefix = ($raw_url | str replace --regex '^git@' "")
          let with_slash = ($no_prefix | str replace ':' '/')
          let no_git_suffix = ($with_slash | str replace --regex '\\.git$' "")
          $"https://($no_git_suffix)"
        } else {
          ($raw_url | str replace --regex '\\.git$' "")
        }

        let branch_result = (do { ^git rev-parse --abbrev-ref HEAD } | complete)
        let branch = if $branch_result.exit_code == 0 {
          ($branch_result.stdout | str trim)
        } else {
          "HEAD"
        }

        let output = if $selection_line_start != $selection_line_end {
          $"($repo_url)/blob/($branch)/($buffer_name)#L($selection_line_start)-L($selection_line_end)"
        } else {
          $"($repo_url)/blob/($branch)/($buffer_name)#L($cursor_line)"
        }

        $output | ^${clipboard}
      }
    '';

    yaziPicker = pkgs.writeNuScriptBin "hx-yazi-picker" ''
      def main [buffer_name?: string] {
        let yazi_result = if (($buffer_name | default "") != "") {
          (do { ^${pkgs.yazi}/bin/yazi $buffer_name --chooser-file /dev/stdout } | complete)
        } else {
          (do { ^${pkgs.yazi}/bin/yazi --chooser-file /dev/stdout } | complete)
        }

        if $yazi_result.exit_code != 0 {
          exit 0
        }

        let paths = (
          $yazi_result.stdout
          | lines
          | where {|path| ($path | str trim) != "" }
        )

        if (($paths | length) == 0) {
          exit 0
        }

        let quoted_paths = (
          $paths
          | each {|path|
              let escaped = ($path | str replace --all '"' '\\"')
              $"\"($escaped)\""
            }
          | str join " "
        )

        ^kitty @ send-text --match "state:overlay_parent" "\u{1b}"
        ^kitty @ send-text --match "state:overlay_parent" $":open ($quoted_paths)"
        ^kitty @ send-text --match "state:overlay_parent" "\r"
      }
    '';

    baseSettings = {
      editor = {
        bufferline = "always";
        cursorline = true;
        color-modes = true;
        true-color = true;
        end-of-line-diagnostics = "hint";
        popup-border = "all";
        cursor-shape = {
          insert = "bar";
          select = "underline";
        };
        file-picker.hidden = false;
        lsp = {
          display-messages = true;
          goto-reference-include-declaration = false;
        };
        inline-diagnostics.cursor-line = "info";
      };

      keys = let
        common = {
          X = "extend_line_above";
          space = {
            q = ":quit";
            Q = ":quit!";
            w = ":write";
            W = ":write!";
            x = ":bc!";
            l = ":sh ${copyLineRef}/bin/hx-copy-line-reference %{buffer_name} %{cursor_line} %{selection_line_start} %{selection_line_end}";
            o = ":sh ${copyLineUrl}/bin/hx-copy-line-url %{buffer_name} %{cursor_line} %{selection_line_start} %{selection_line_end}";
            "C-r" = ":rla";
          };
        };
      in {
        normal =
          common
          // {
            "C-g" = ":sh kitty @ launch --copy-env --type=overlay --cwd=current --window-title=current ${pkgs.lazygit}/bin/lazygit >/dev/null";
            "C-f" = ":sh kitty @ launch --copy-env --type=overlay --cwd=current --window-title=current ${yaziPicker}/bin/hx-yazi-picker %{buffer_name} >/dev/null";
            "C-t" = ":sh kitty @ launch --copy-env --type=overlay --cwd=current --window-title=current >/dev/null";
            "C-l" = "goto_next_buffer";
            "C-h" = "goto_previous_buffer";
            "C-x" = ":buffer-close";
          };
        select = common;
      };
    };

    languages = {
      language = [
        {
          name = "rust";
          language-servers = ["rust-analyzer"];
        }
        {
          name = "markdown";
          language-servers = ["marksman"];
        }
        {
          name = "nix";
          language-servers = [
            "nil"
            "nixd"
          ];
          formatter = {
            command = "alejandra";
            args = ["-"];
          };
          auto-format = true;
        }
        {
          name = "dart";
          language-servers = ["dart"];
        }
        {
          name = "toml";
          language-servers = ["taplo"];
          formatter = {
            command = "taplo";
            args = [
              "fmt"
              "-"
            ];
          };
          auto-format = true;
        }
      ];

      language-server = {
        rust-analyzer = {
          command = "rust-analyzer";
          config = {
            checkOnSave.enable = true;
            procMacro.enable = true;
          };
        };

        nixd = {
          command = "nixd";
          args = ["--semantic-tokens=true"];
        };

        dart.command = "dart";
      };
    };
  in {
    environment.systemPackages = with pkgs; [
      helix
      nil
      nixd
    ];

    sumi.file = {
      "helix/config.toml" = {
        dependsOn = ["theme"];
        render = ctx: let
          theme = ctx.values.theme;
        in
          tomlFormat.generate "sumi-helix-config-${ctx.selection.theme}.toml" (baseSettings // {theme = theme.meta.helix or ctx.selection.theme;});
      };

      "helix/languages.toml".source = tomlFormat.generate "sumi-helix-languages.toml" languages;
      "helix/themes/modus.toml".source = ./themes/modus.toml;
      "helix/themes/melissa-light.toml".source = ./themes/melissa-light.toml;
      "helix/themes/space-age.toml".source = ./themes/space-age.toml;
      "helix/themes/gruvbox.toml".source = ./themes/gruvbox.toml;
    };

    sumi.program.helix.reload =
      if pkgs.stdenv.isDarwin
      then "/usr/bin/pkill -USR1 hx || true"
      else "${pkgs.procps}/bin/pkill -USR1 hx || true";
  };
in {
  flake.modules.nixos.helix = {pkgs, ...}: mkHelixModule {inherit pkgs;};
  flake.modules.darwin.helix = {pkgs, ...}: mkHelixModule {inherit pkgs;};
}
