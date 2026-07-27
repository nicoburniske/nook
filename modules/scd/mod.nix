{inputs, ...}: {
  inputs.scd = {
    url = "github:nicoburniske/steam-controller-daemon/master";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixosModules.scd = {
    host,
    pkgs,
    ...
  }: {
    imports = [inputs.scd.nixosModules.default];

    services.scd = {
      enable = true;
      configFile = ./config.toml;
    };
    users.users.${host.user}.extraGroups = ["scd-control"];

    sumi = {
      configFile."scd/osk.toml" = {
        watch = "theme";
        value = ctx:
          (pkgs.formats.toml {}).generate "scd-osk.toml" {
            font = ctx.value.fonts.sansSerif.file;
            colors = with ctx.value.colors; {
              background = "#${base00}";
              border = "#${base03}";
              key = "#${base01}";
              special = "#${base02}";
              hover = "#${base05}";
              pressed = "#${base0D}";
              pressed_foreground = "#${base00}";
              foreground = "#${base05}";
              muted = "#${base04}";
              dim = "#${base03}";
              hint_paddle = "#${base02}";
              hint_control = "#${base01}";
              shadow = "#000000";
            };
          };
      };
      hook.scd-osk = {
        watch = "theme";
        command = ''
          ${pkgs.systemd}/bin/systemctl --user reset-failed scd-osk.service
          ${pkgs.systemd}/bin/systemctl --user restart scd-osk.service
        '';
      };
    };
  };
}
