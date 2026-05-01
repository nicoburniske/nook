{...}: {
  flake.modules.nixos.fuzzel = {pkgs, ...}: let
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
  in {
    environment.systemPackages = [
      pkgs.fuzzel
      pkgs.numix-icon-theme-circle
    ];

    sumi.configFile."fuzzel/fuzzel.ini" = {
      watch = ["theme"];
      value = ctx: let
        theme = ctx.values.theme;
        c = theme.colors;
        opacity = theme.opacity.popups or theme.opacity.terminal or 1.0;
        opacityHex = mkHexByte (builtins.ceil (opacity * 255.0));
      in ''
        [main]
        font=${theme.fonts.sansSerif.name}:size=${toString theme.fonts.sizes.popups}
        terminal=${pkgs.kitty}/bin/kitty
        layer=overlay
        keyboard-focus=on-demand
        width=40
        lines=20
        filter-desktop=yes
        list-executables-in-path=no
        horizontal-pad=20
        vertical-pad=20
        inner-pad=8
        icons-enabled=yes
        icon-theme=Numix-Circle

        [border]
        width=2
        radius=0

        [colors]
        background=${c.base00}${opacityHex}
        text=${c.base05}ff
        placeholder=${c.base03}ff
        prompt=${c.base05}ff
        input=${c.base05}ff
        match=${c.base0A}ff
        selection=${c.base03}ff
        selection-text=${c.base05}ff
        selection-match=${c.base0A}ff
        counter=${c.base06}ff
        border=${c.base0D}ff

        [key-bindings]
        prev=none
        prev-with-wrap=Up Control+p
        next=none
        next-with-wrap=Down Control+n
      '';
    };
  };
}
