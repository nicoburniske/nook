{pkgs, ...}: let
  mkHexByte = value: let
    digits = "0123456789abcdef";
    bounded =
      if value < 0
      then 0
      else if value > 255
      then 255
      else value;
    hi = builtins.div bounded 16;
    lo = bounded - (hi * 16);
    digit = idx: builtins.substring idx 1 digits;
  in "${digit hi}${digit lo}";

  alpha = color: opacityHex: "${color}${opacityHex}";
in {
  environment.systemPackages = [
    pkgs.rofi
  ];

  sumi.configFile."rofi/niri-cmd.rasi" = {
    watch = "theme";
    value = ctx: let
      theme = ctx.value;
      c = theme.colors.withHashtag;
      opacity = theme.opacity.popups or theme.opacity.terminal or 1.0;
      opacityHex = mkHexByte (builtins.ceil (opacity * 255.0));
      font = "${theme.fonts.sansSerif.name} ${toString theme.fonts.sizes.popups}";
    in ''
      configuration {
        font: "${font}";
        show-icons: false;
        fixed-num-lines: true;
        matching: "fuzzy";
        sorting-method: "fzf";
        case-sensitive: false;
        click-to-exit: true;
        steal-focus: false;
        kb-row-up: "Up,Control+k";
        kb-row-down: "Down,Control+j";
        kb-accept-entry: "Return,Right,Control+l";
        kb-cancel: "Escape";
        kb-mode-complete: "";
        kb-move-char-back: "";
        kb-move-char-forward: "";
        kb-remove-char-back: "BackSpace";
        kb-remove-to-eol: "";
        kb-remove-to-sol: "";
        kb-custom-1: "Left,Control+h";
      }

      * {
        background-color: transparent;
        text-color: ${c.base05};
        border-color: ${c.base0D};
        separatorcolor: ${c.base03};
      }

      window {
        width: 40em;
        padding: 20px;
        border: 2px;
        border-radius: 0px;
        background-color: ${alpha c.base00 opacityHex};
      }

      mainbox {
        padding: 0px;
        spacing: 8px;
        border: 0px;
        background-color: transparent;
      }

      inputbar {
        padding: 0px 0px 8px 0px;
        spacing: 8px;
        border: 0px 0px 1px 0px;
        border-color: ${c.base03};
        background-color: transparent;
        children: [ prompt, entry ];
      }

      prompt {
        text-color: ${c.base0D};
        background-color: transparent;
      }

      entry {
        placeholder: "";
        placeholder-color: ${c.base04};
        text-color: ${c.base05};
        background-color: transparent;
        cursor-color: ${c.base0A};
      }

      listview {
        lines: 16;
        fixed-height: false;
        scrollbar: false;
        spacing: 2px;
        padding: 0px;
        border: 0px;
        background-color: transparent;
      }

      element {
        padding: 6px 8px;
        spacing: 8px;
        border: 0px;
        border-radius: 0px;
        cursor: pointer;
        background-color: transparent;
      }

      element normal.normal,
      element alternate.normal {
        background-color: transparent;
        text-color: ${c.base05};
      }

      element selected.normal {
        background-color: ${c.base03};
        text-color: ${c.base05};
      }

      element-text {
        background-color: transparent;
        text-color: inherit;
        highlight: bold ${c.base0A};
      }

      element-icon {
        size: 0px;
      }

      message,
      textbox {
        background-color: transparent;
        text-color: ${c.base04};
      }
    '';
  };
}
