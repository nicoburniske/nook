{...}: {
  flake.modules.nixos.rofi = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.rofi
    ];

    sumi.file."rofi/config.rasi" = {
      dependsOn = ["theme"];
      render = ctx: let
        theme = ctx.values.theme;
      in
        with theme.colors.withHashtag; ''
          configuration {
            modi: "drun";
            show-icons: false;

            display-drun: "";
            display-run: "";
            display-filebrowser: "";
            display-window: "";
            display-emoji: "󰞅";
            display-calc: "󰃬";

            drun-display-format: "{name}";
            window-format: "{w} · {c} · {t}";

            kb-mode-next: "Control+l";
            kb-mode-previous: "Control+h";
            kb-row-up: "Control+k,Up";
            kb-row-down: "Control+j,Down";
            kb-remove-char-forward: "";
            kb-remove-to-sol: "";
            kb-remove-to-eol: "";
            kb-mode-complete: "";
            kb-remove-char-back: "BackSpace";
            kb-accept-entry: "Return";
          }

          * {
            selected: ${base0D};
            foreground: ${base05};
            background: ${base00};
            background-alt: ${base01};
            urgent: ${base08};
            active: ${base0A};
            border: ${base03};

            border-colour: @selected;
            handle-colour: @foreground;
            background-colour: @background;
            foreground-colour: @foreground;
            alternate-background: @background-alt;
            normal-background: @background;
            normal-foreground: @foreground;
            urgent-background: @urgent;
            urgent-foreground: @background;
            active-background: @active;
            active-foreground: @background;
            selected-normal-background: @selected;
            selected-normal-foreground: @background;
            selected-urgent-background: @active;
            selected-urgent-foreground: @background;
            selected-active-background: @urgent;
            selected-active-foreground: @background;
            alternate-normal-background: @background;
            alternate-normal-foreground: @foreground;
            alternate-urgent-background: @urgent;
            alternate-urgent-foreground: @background;
            alternate-active-background: @active;
            alternate-active-foreground: @background;
          }

          window {
            transparency: "real";
            location: center;
            anchor: center;
            fullscreen: false;
            width: 600px;
            x-offset: 0px;
            y-offset: 0px;
            enabled: true;
            margin: 0px;
            padding: 0px;
            border: 2px solid;
            border-radius: 0px;
            border-color: @border;
            cursor: default;
            background-color: @background-colour;
          }

          mainbox {
            enabled: true;
            spacing: 20px;
            margin: 0px;
            padding: 40px;
            border: 0px solid;
            border-radius: 0px 0px 0px 0px;
            border-color: @border-colour;
            background-color: transparent;
            children: [inputbar, message, listview, mode-switcher];
          }

          inputbar {
            enabled: true;
            spacing: 10px;
            margin: 0px;
            padding: 8px;
            border: 0px solid;
            border-radius: 4px;
            border-color: @border-colour;
            background-color: @alternate-background;
            text-color: @foreground-colour;
            children: [entry];
          }

          prompt {
            enabled: true;
            background-color: inherit;
            text-color: inherit;
          }

          textbox-prompt-colon {
            enabled: true;
            expand: false;
            str: "::";
            background-color: inherit;
            text-color: inherit;
          }

          entry {
            enabled: true;
            background-color: inherit;
            text-color: inherit;
            cursor: text;
            placeholder: "search...";
            placeholder-color: inherit;
          }

          num-filtered-rows {
            enabled: true;
            expand: false;
            background-color: inherit;
            text-color: inherit;
          }

          textbox-num-sep {
            enabled: true;
            expand: false;
            str: "/";
            background-color: inherit;
            text-color: inherit;
          }

          num-rows {
            enabled: true;
            expand: false;
            background-color: inherit;
            text-color: inherit;
          }

          case-indicator {
            enabled: true;
            background-color: inherit;
            text-color: inherit;
          }

          listview {
            enabled: true;
            columns: 1;
            lines: 9;
            cycle: true;
            dynamic: true;
            scrollbar: false;
            layout: vertical;
            reverse: false;
            fixed-height: true;
            fixed-columns: true;
            spacing: 5px;
            margin: 0px;
            padding: 0px;
            border: 0px solid;
            border-radius: 0px;
            border-color: @border-colour;
            background-color: transparent;
            text-color: @foreground-colour;
            cursor: default;
          }

          scrollbar {
            handle-width: 5px;
            handle-color: @handle-colour;
            border-radius: 8px;
            background-color: @alternate-background;
          }

          element {
            enabled: true;
            spacing: 8px;
            margin: 0px;
            padding: 8px;
            border: 0px solid;
            border-radius: 4px;
            border-color: @border-colour;
            background-color: transparent;
            text-color: @foreground-colour;
            cursor: pointer;
          }

          element normal.normal {
            background-color: @normal-background;
            text-color: @normal-foreground;
          }

          element normal.urgent {
            background-color: @urgent-background;
            text-color: @urgent-foreground;
          }

          element normal.active {
            background-color: @active-background;
            text-color: @active-foreground;
          }

          element selected.normal {
            background-color: @normal-foreground;
            text-color: @normal-background;
          }

          element selected.urgent {
            background-color: @selected-urgent-background;
            text-color: @selected-urgent-foreground;
          }

          element selected.active {
            background-color: @selected-active-background;
            text-color: @selected-active-foreground;
          }

          element alternate.normal {
            background-color: @alternate-normal-background;
            text-color: @alternate-normal-foreground;
          }

          element alternate.urgent {
            background-color: @alternate-urgent-background;
            text-color: @alternate-urgent-foreground;
          }

          element alternate.active {
            background-color: @alternate-active-background;
            text-color: @alternate-active-foreground;
          }

          element-icon {
            background-color: transparent;
            text-color: inherit;
            size: 24px;
            cursor: inherit;
          }

          element-text {
            background-color: transparent;
            text-color: inherit;
            highlight: inherit;
            cursor: inherit;
            vertical-align: 0.5;
            horizontal-align: 0.0;
          }

          mode-switcher {
            enabled: true;
            spacing: 10px;
            margin: 0px;
            padding: 0px;
            border: 0px solid;
            border-radius: 0px;
            border-color: @border-colour;
            background-color: transparent;
            text-color: @foreground-colour;
          }

          button {
            padding: 8px;
            border: 0px solid;
            border-radius: 4px;
            border-color: @border-colour;
            background-color: @alternate-background;
            text-color: inherit;
            cursor: pointer;
          }

          button selected {
            background-color: @normal-foreground;
            text-color: @normal-background;
          }

          message {
            enabled: true;
            margin: 0px;
            padding: 0px;
            border: 0px solid;
            border-radius: 0px;
            border-color: @border-colour;
            background-color: transparent;
            text-color: @foreground-colour;
          }

          textbox {
            padding: 8px;
            border: 0px solid;
            border-radius: 4px;
            border-color: @border-colour;
            background-color: @alternate-background;
            text-color: @foreground-colour;
            vertical-align: 0.5;
            horizontal-align: 0.0;
            highlight: none;
            placeholder-color: @foreground-colour;
            blink: true;
            markup: true;
          }

          error-message {
            padding: 10px;
            border: 0px solid;
            border-radius: 4px;
            border-color: @border-colour;
            background-color: @background-colour;
            text-color: @foreground-colour;
          }
        '';
    };

    sumi.program.rofi.reload = [];
  };
}
