{
  lib,
  pkgs,
  ...
}: let
  # TODO: helix themes - voxed, seoul256-dark-hard, iroasetau
  berkeleyMono = import ./berkeley-mono.nix {inherit pkgs;};

  mkOpacity = opacity:
    if pkgs.stdenv.isLinux
    then opacity
    else 1.0;

  mkTheme = base: let
    withHashtag = lib.mapAttrs (_: value: "#${value}") base.colors;
  in
    base
    // {
      colors = base.colors // {inherit withHashtag;};
    };

  sharedTheme = {
    opacity = {
      terminal = mkOpacity 0.90;
    };

    fonts = {
      monospace = {
        package = berkeleyMono;
        name = "Berkeley Mono";
      };

      sansSerif = {
        package = berkeleyMono;
        name = "Berkeley Mono";
      };

      serif = {
        package = berkeleyMono;
        name = "Berkeley Mono";
      };

      emoji = {
        package = pkgs.nerd-fonts.symbols-only;
        name = "Symbols Nerd Font";
      };

      sizes = {
        applications = 12;
        terminal = 13;
        desktop = 12;
        popups = 12;
      };
    };
  };
in {
  gruvbox = mkTheme (
    sharedTheme
    // {
      polarity = "dark";
      image = ../assets/wallpapers/the-backwater.jpg;
      colors = {
        base00 = "1d2021";
        base01 = "3c3836";
        base02 = "504945";
        base03 = "665c54";
        base04 = "bdae93";
        base05 = "d5c4a1";
        base06 = "ebdbb2";
        base07 = "fbf1c7";
        base08 = "fb4934";
        base09 = "fe8019";
        base0A = "fabd2f";
        base0B = "b8bb26";
        base0C = "8ec07c";
        base0D = "83a598";
        base0E = "d3869b";
        base0F = "d65d0e";
      };
    }
  );

  space-age = mkTheme (
    sharedTheme
    // {
      polarity = "dark";
      image = ../assets/wallpapers/space.jpg;
      meta = {
        helix = "space-age";
      };
      colors = {
        base00 = "190f0f";
        base01 = "2c1617";
        base02 = "442022";
        base03 = "704144";
        base04 = "cebabf";
        base05 = "cebabf";
        base06 = "e97e8a";
        base07 = "e97e8a";
        base08 = "d2505f";
        base09 = "ff7550";
        base0A = "eb842b";
        base0B = "8ea84d";
        base0C = "65aba3";
        base0D = "65aba3";
        base0E = "ce8b9f";
        base0F = "d95362";
      };
    }
  );

  modus = mkTheme (
    sharedTheme
    // {
      polarity = "light";
      image = ../assets/wallpapers/light-painting.jpeg;
      meta = {
        helix = "modus";
      };
      colors = {
        base00 = "fbf7f0";
        base01 = "f1d5d0";
        base02 = "efe9dd";
        base03 = "9f9690";
        base04 = "595959";
        base05 = "000000";
        base06 = "193668";
        base07 = "000000";
        base08 = "a0132f";
        base09 = "972500";
        base0A = "6d5000";
        base0B = "006300";
        base0C = "005f5f";
        base0D = "3546c2";
        base0E = "531ab6";
        base0F = "894000";
      };
    }
  );

  melissa-light = mkTheme (
    sharedTheme
    // {
      polarity = "light";
      image = ../assets/wallpapers/church-gentleman.jpg;
      meta = {
        helix = "melissa-light";
      };
      colors = {
        base00 = "fff6d8";
        base01 = "f5e9cb";
        base02 = "e7d7c6";
        base03 = "c5baa6";
        base04 = "68708a";
        base05 = "484431";
        base06 = "80431a";
        base07 = "a07f00";
        base08 = "c74400";
        base09 = "ba5205";
        base0A = "a26310";
        base0B = "007a0a";
        base0C = "0f708a";
        base0D = "375cc6";
        base0E = "6448ca";
        base0F = "946830";
      };
    }
  );

  ashen = mkTheme (
    sharedTheme
    // {
      polarity = "dark";
      image = ../assets/wallpapers/ashen.png;
      meta = {
        helix = "ashen";
      };
      opacity = {
        terminal = mkOpacity 0.95;
      };
      colors = {
        base00 = "121212";
        base01 = "1d1d1d";
        base02 = "252525";
        base03 = "363636";
        base04 = "737373";
        base05 = "b4b4b4";
        base06 = "d5d5d5";
        base07 = "e5e5e5";
        base08 = "c53030";
        base09 = "c4693d";
        base0A = "e5a72a";
        base0B = "df6464";
        base0C = "d87c4a";
        base0D = "4a8b8b";
        base0E = "b14242";
        base0F = "89492a";
      };
    }
  );
}
