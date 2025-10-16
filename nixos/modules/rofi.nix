{
  lib,
  config,
  ...
}: {
  programs.rofi = let
    colors = config.lib.stylix.colors.withHashtag;
    l = config.lib.formats.rasi.mkLiteral;
    px = x: l "${toString x}px";
  in {
    enable = true;
    extraConfig = {
      modi = "drun,run";
      show-icons = false;

      display-drun = "";
      display-run = "";
      display-filebrowser = "";
      display-window = "";

      drun-display-format = "{name}";
      window-format = "{w} · {c} · {t}";
    };
    theme = lib.mkForce {
      "*" = {
        selected = l "${colors.base0D}";
        foreground = l "${colors.base05}";
        background = l "${colors.base00}";
        background-alt = l "${colors.base01}";
        urgent = l "${colors.base08}";
        active = l "${colors.base0A}";

        border-colour = l "@selected";
        handle-colour = l "@foreground";
        background-colour = l "@background";
        foreground-colour = l "@foreground";
        alternate-background = l "@background-alt";
        normal-background = l "@background";
        normal-foreground = l "@foreground";
        urgent-background = l "@urgent";
        urgent-foreground = l "@background";
        active-background = l "@active";
        active-foreground = l "@background";
        selected-normal-background = l "@selected";
        selected-normal-foreground = l "@background";
        selected-urgent-background = l "@active";
        selected-urgent-foreground = l "@background";
        selected-active-background = l "@urgent";
        selected-active-foreground = l "@background";
        alternate-normal-background = l "@background";
        alternate-normal-foreground = l "@foreground";
        alternate-urgent-background = l "@urgent";
        alternate-urgent-foreground = l "@background";
        alternate-active-background = l "@active";
        alternate-active-foreground = l "@background";
      };

      window = {
        transparency = "real";
        location = l "center";
        anchor = l "center";
        fullscreen = false;
        width = px 400;
        x-offset = px 0;
        y-offset = px 0;

        enabled = true;
        margin = px 0;
        padding = px 0;
        border = l "0px solid";
        border-radius = px 8;
        border-color = l "@border-colour";
        cursor = l "default";
        background-color = l "@background-colour";
      };

      mainbox = {
        enabled = true;
        spacing = px 10;
        margin = px 0;
        padding = px 30;
        border = l "0px solid";
        border-radius = l "0px";
        border-color = l "@border-colour";
        background-color = l "transparent";
        children = l "[inputbar, message, listview, mode-switcher]";
      };

      inputbar = {
        enabled = true;
        spacing = px 10;
        margin = px 0;
        padding = px 0;
        border = l "0px solid";
        border-radius = px 0;
        border-color = l "@border-colour";
        background-color = l "transparent";
        text-color = l "@foreground-colour";
        children = l "[prompt, entry]";
      };

      prompt = {
        enabled = true;
        background-color = l "inherit";
        text-color = l "inherit";
      };

      textbox-prompt-colon = {
        enabled = true;
        expand = false;
        str = "::";
        background-color = l "inherit";
        text-color = l "inherit";
      };

      entry = {
        enabled = true;
        background-color = l "inherit";
        text-color = l "inherit";
        cursor = l "text";
        placeholder = "search...";
        placeholder-color = l "inherit";
      };

      num-filtered-rows = {
        enabled = true;
        expand = false;
        background-color = l "inherit";
        text-color = l "inherit";
      };

      textbox-num-sep = {
        enabled = true;
        expand = false;
        str = "/";
        background-color = l "inherit";
        text-color = l "inherit";
      };

      num-rows = {
        enabled = true;
        expand = false;
        background-color = l "inherit";
        text-color = l "inherit";
      };

      case-indicator = {
        enabled = true;
        background-color = l "inherit";
        text-color = l "inherit";
      };

      listview = {
        enabled = true;
        columns = 1;
        lines = 6;
        cycle = true;
        dynamic = true;
        scrollbar = false;
        layout = l "vertical";
        reverse = false;
        fixed-height = true;
        fixed-columns = true;

        spacing = px 5;
        margin = px 0;
        padding = px 0;
        border = l "0px solid";
        border-radius = px 0;
        border-color = l "@border-colour";
        background-color = l "transparent";
        text-color = l "@foreground-colour";
        cursor = l "default";
      };

      scrollbar = {
        handle-width = px 5;
        handle-color = l "@handle-colour";
        border-radius = px 8;
        background-color = l "@alternate-background";
      };

      element = {
        enabled = true;
        spacing = px 8;
        margin = px 0;
        padding = px 8;
        border = l "0px solid";
        border-radius = px 4;
        border-color = l "@border-colour";
        background-color = l "transparent";
        text-color = l "@foreground-colour";
        cursor = l "pointer";
      };

      "element normal.normal" = {
        background-color = l "@normal-background";
        text-color = l "@normal-foreground";
      };

      "element normal.urgent" = {
        background-color = l "@urgent-background";
        text-color = l "@urgent-foreground";
      };

      "element normal.active" = {
        background-color = l "@active-background";
        text-color = l "@active-foreground";
      };

      "element selected.normal" = {
        background-color = l "@normal-foreground";
        text-color = l "@normal-background";
      };

      "element selected.urgent" = {
        background-color = l "@selected-urgent-background";
        text-color = l "@selected-urgent-foreground";
      };

      "element selected.active" = {
        background-color = l "@selected-active-background";
        text-color = l "@selected-active-foreground";
      };

      "element alternate.normal" = {
        background-color = l "@alternate-normal-background";
        text-color = l "@alternate-normal-foreground";
      };

      "element alternate.urgent" = {
        background-color = l "@alternate-urgent-background";
        text-color = l "@alternate-urgent-foreground";
      };

      "element alternate.active" = {
        background-color = l "@alternate-active-background";
        text-color = l "@alternate-active-foreground";
      };

      element-icon = {
        background-color = l "transparent";
        text-color = l "inherit";
        size = px 24;
        cursor = l "inherit";
      };

      element-text = {
        background-color = l "transparent";
        text-color = l "inherit";
        highlight = l "inherit";
        cursor = l "inherit";
        vertical-align = l "0.5";
        horizontal-align = l "0.0";
      };

      mode-switcher = {
        enabled = true;
        spacing = px 10;
        margin = px 0;
        padding = px 0;
        border = l "0px solid";
        border-radius = px 0;
        border-color = l "@border-colour";
        background-color = l "transparent";
        text-color = l "@foreground-colour";
      };

      button = {
        padding = px 8;
        border = l "0px solid";
        border-radius = px 4;
        border-color = l "@border-colour";
        background-color = l "@alternate-background";
        text-color = l "inherit";
        cursor = l "pointer";
      };

      "button selected" = {
        background-color = l "@normal-foreground";
        text-color = l "@normal-background";
      };

      message = {
        enabled = true;
        margin = px 0;
        padding = px 0;
        border = l "0px solid";
        border-radius = l "0px";
        border-color = l "@border-colour";
        background-color = l "transparent";
        text-color = l "@foreground-colour";
      };

      textbox = {
        padding = px 8;
        border = l "0px solid";
        border-radius = px 4;
        border-color = l "@border-colour";
        background-color = l "@alternate-background";
        text-color = l "@foreground-colour";
        vertical-align = l "0.5";
        horizontal-align = l "0.0";
        highlight = l "none";
        placeholder-color = l "@foreground-colour";
        blink = true;
        markup = true;
      };

      error-message = {
        padding = px 10;
        border = l "0px solid";
        border-radius = px 4;
        border-color = l "@border-colour";
        background-color = l "@background-colour";
        text-color = l "@foreground-colour";
      };
    };
  };
}
