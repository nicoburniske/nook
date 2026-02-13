# Velum (Draft)

Velum is a small runtime for theme-aware config swapping on NixOS.

Design goals in this draft:

- Centralized theme definitions
- Explicit file registrations (no auto-discovery)
- Full-file rendering per theme
- Symlink-only activation
- Reload hooks after switch

## Add Velum to a NixOS host

```nix
{
  inputs.velum.url = "path:./velum";

  outputs = { self, nixpkgs, velum, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        velum.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

## Define themes

```nix
{
  velum = {
    enable = true;
    defaultTheme = "gruvbox";

    themes = {
      gruvbox = {
        base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
        polarity = "dark";
      };

      modus = {
        base16Scheme = ./themes/modus-operandi-tinted.yaml;
        polarity = "light";
      };
    };
  };
}
```

## Register files and hooks

```nix
{
  velum.programs.hyprland = {
    "hypr/hyprland.conf".render = theme: with theme.colors.withHashtag; ''
      general {
        col.active_border = rgb(${base0D})
        col.inactive_border = rgb(${base03})
      }
    '';

    reload = "hyprctl reload";
  };
}
```

Each file entry must set exactly one of:

- `render = theme: "..."` (or a generated file path/derivation)
- `text = "..."`
- `source = ./path-or-directory`

## Out-of-store Symlinks

Velum exposes a helper similar to Home Manager:

```nix
{
  velum.programs.quickshell = {
    "quickshell/components".source =
      config.lib.velum.mkOutOfStoreSymlink "${config.nook.paths.flakeRoot}/nixos/modules/quickshell/components";
  };
}
```

## Optional `mkConfig` Helper

`config.lib.velum.mkConfig` can define app config and Velum registration
in one object:

```nix
{
  imports = [
    (config.lib.velum.mkConfig "ghostty" {
      program = {
        # optional programs.ghostty fields
      };

      velum = {
        "ghostty/config".render = theme: "...";
        reload = [];
      };
    })
  ];
}
```

## Runtime commands

```sh
velum list
velum current
velum show gruvbox
velum switch modus
velum doctor
```

The module installs a host-wrapped `velum` command with a generated manifest.
The manifest is also exposed at `/etc/velum/manifest.json`.
