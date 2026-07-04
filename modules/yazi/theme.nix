theme: let
  c = theme.colors.withHashtag;
  brown = c.base09;
  mkFg = fg: {inherit fg;};
  mkBg = bg: {inherit bg;};
  mkBoth = fg: bg: {inherit fg bg;};
  mkSame = color: mkBoth color color;
in {
  mgr = {
    cwd = mkFg c.base0C;
    find_keyword =
      (mkFg c.base0B)
      // {
        bold = true;
      };
    find_position = mkFg c.base0E;
    marker_selected = mkSame c.base0A;
    marker_copied = mkSame c.base0B;
    marker_cut = mkSame c.base08;
    border_style = mkFg c.base04;

    count_copied = mkBoth c.base00 c.base0B;
    count_cut = mkBoth c.base00 c.base08;
    count_selected = mkBoth c.base00 c.base0A;
  };

  indicator = rec {
    current =
      (mkBg c.base02)
      // {
        bold = true;
      };
    preview = current;
  };

  tabs = {
    active =
      (mkBoth c.base00 c.base0D)
      // {
        bold = true;
      };
    inactive = mkBoth c.base0D c.base01;
  };

  mode = {
    normal_main =
      (mkBoth c.base00 c.base0D)
      // {
        bold = true;
      };
    normal_alt = mkBoth c.base0D c.base00;
    select_main =
      (mkBoth c.base00 c.base0B)
      // {
        bold = true;
      };
    select_alt = mkBoth c.base0B c.base00;
    unset_main =
      (mkBoth c.base00 brown)
      // {
        bold = true;
      };
    unset_alt = mkBoth brown c.base00;
  };

  status = {
    progress_label = mkBoth c.base05 c.base00;
    progress_normal = mkBoth c.base05 c.base00;
    progress_error = mkBoth c.base08 c.base00;
    perm_type = mkFg c.base0D;
    perm_read = mkFg c.base0A;
    perm_write = mkFg c.base08;
    perm_exec = mkFg c.base0B;
    perm_sep = mkFg c.base0C;
  };

  pick = {
    border = mkFg c.base0D;
    active = mkFg c.base0E;
    inactive = mkFg c.base05;
  };

  input = {
    border = mkFg c.base0D;
    title = mkFg c.base05;
    value = mkFg c.base05;
    selected = mkBg c.base03;
  };

  completion = {
    border = mkFg c.base0D;
    active = mkBoth c.base0E c.base03;
    inactive = mkFg c.base05;
  };

  tasks = {
    border = mkFg c.base0D;
    title = mkFg c.base05;
    hovered = mkBoth c.base05 c.base03;
  };

  which = {
    mask = mkBg c.base02;
    cand = mkFg c.base0C;
    rest = mkFg brown;
    desc = mkFg c.base05;
    separator_style = mkFg c.base04;
  };

  help = {
    on = mkFg c.base0E;
    run = mkFg c.base0C;
    desc = mkFg c.base05;
    hovered = mkBoth c.base05 c.base03;
    footer = mkFg c.base05;
  };

  filetype.rules = [
    {
      mime = "image/*";
      fg = c.base0C;
    }
    {
      mime = "video/*";
      fg = c.base0A;
    }
    {
      mime = "audio/*";
      fg = c.base0A;
    }
    {
      mime = "application/zip";
      fg = c.base0E;
    }
    {
      mime = "application/gzip";
      fg = c.base0E;
    }
    {
      mime = "application/tar";
      fg = c.base0E;
    }
    {
      mime = "application/bzip";
      fg = c.base0E;
    }
    {
      mime = "application/bzip2";
      fg = c.base0E;
    }
    {
      mime = "application/7z-compressed";
      fg = c.base0E;
    }
    {
      mime = "application/rar";
      fg = c.base0E;
    }
    {
      mime = "application/xz";
      fg = c.base0E;
    }
    {
      mime = "application/doc";
      fg = c.base0B;
    }
    {
      mime = "application/pdf";
      fg = c.base0B;
    }
    {
      mime = "application/rtf";
      fg = c.base0B;
    }
    {
      mime = "application/vnd.*";
      fg = c.base0B;
    }
    {
      url = "*/";
      fg = c.base0D;
      bold = true;
    }
    {
      mime = "*";
      fg = c.base05;
    }
  ];
}
