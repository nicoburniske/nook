{pkgs, ...}: let
  tomlFormat = pkgs.formats.toml {};

  clipboard = "wl-copy";

  copyLineRef = pkgs.writeShellScriptBin "hx-copy-line-reference" ''
    buffer_name="$1"
    cursor_line="$2"
    selection_line_start="$3"
    selection_line_end="$4"

    if [ "$selection_line_start" != "$selection_line_end" ]; then
      printf "%s:%s-%s" "$buffer_name" "$selection_line_start" "$selection_line_end" | ${clipboard}
    else
      printf "%s:%s" "$buffer_name" "$cursor_line" | ${clipboard}
    fi
  '';

  copyLineUrl = pkgs.writeShellScriptBin "hx-copy-line-url" ''
    buffer_name="$1"
    cursor_line="$2"
    selection_line_start="$3"
    selection_line_end="$4"

    url=$(git remote get-url origin 2>/dev/null)

    if [ -z "$url" ]; then
      return 1
    fi

    url=''${url#git@}
    url=''${url/:/\/}
    url=''${url%.git}
    url="https://''$url"

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")

    if [ "$selection_line_start" != "$selection_line_end" ]; then
      printf "%s/blob/%s/%s#L%s-L%s" "$url" "$branch" "$buffer_name" "$selection_line_start" "$selection_line_end" | ${clipboard}
    else
      printf "%s/blob/%s/%s#L%s" "$url" "$branch" "$buffer_name" "$cursor_line" | ${clipboard}
    fi
  '';

  yaziPicker = pkgs.writeShellScriptBin "hx-yazi-picker" ''
    buffer_name="$1"

    if [ -n "$buffer_name" ]; then
      paths=$(
        ${pkgs.yazi}/bin/yazi "$buffer_name" --chooser-file=/dev/stdout |
          while IFS= read -r path || [ -n "$path" ]; do
            printf "%q " "$path"
          done
      )
    else
      paths=$(
        ${pkgs.yazi}/bin/yazi --chooser-file=/dev/stdout |
          while IFS= read -r path || [ -n "$path" ]; do
            printf "%q " "$path"
          done
      )
    fi

    if [[ -n "$paths" ]]; then
      kitty @ send-text --match 'state:overlay_parent' '\x1b'
      kitty @ send-text --match 'state:overlay_parent' ":open $paths"
      kitty @ send-text --match 'state:overlay_parent' '\r'
    fi
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
          "C-g" = ":sh kitty @ launch --type=overlay --cwd=\"$(pwd)\" --window-title=current lazygit >/dev/null";
          "C-f" = ":sh kitty @ launch --type=overlay --cwd=\"$(pwd)\" --window-title=current ${yaziPicker}/bin/hx-yazi-picker %{buffer_name} >/dev/null";
          "C-t" = ":sh kitty @ launch --type=overlay --cwd=\"$(pwd)\" --window-title=current >/dev/null";
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

  velum.programs.helix = {
    "helix/config.toml".render = theme:
      tomlFormat.generate "velum-helix-config-${theme.slug}.toml" (baseSettings // {theme = theme.slug;});

    "helix/languages.toml".source = tomlFormat.generate "velum-helix-languages.toml" languages;
    "helix/themes/modus.toml".source = ./themes/modus.toml;
    "helix/themes/melissa-dark.toml".source = ./themes/melissa-dark.toml;
    "helix/themes/melissa-light.toml".source = ./themes/melissa-light.toml;
    "helix/themes/space-age.toml".source = ./themes/space-age.toml;
    "helix/themes/gruvbox.toml".source = ./themes/gruvbox.toml;

    reload = "${pkgs.procps}/bin/pkill -USR1 hx || true";
  };
}
