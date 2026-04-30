{...}: {
  flake.modules.nixos.compositor = {lib, ...}: {
    options.compositor.shell.command = lib.mkOption {
      type = lib.types.str;
      default = "noctalia-shell";
      description = "Command started by the active compositor for the desktop shell.";
    };

    config = {
      systemd.user.targets.compositor-session = {
        description = "Shared compositor session";
        documentation = ["man:systemd.special(7)"];
        bindsTo = ["graphical-session.target"];
        wants = ["graphical-session-pre.target"];
        after = ["graphical-session-pre.target"];
      };
    };
  };
}
