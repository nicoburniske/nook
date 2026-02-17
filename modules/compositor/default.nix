{...}: {
  flake.modules.nixos.compositor = {
    systemd.user.targets.compositor-session = {
      description = "Shared compositor session";
      documentation = ["man:systemd.special(7)"];
      bindsTo = ["graphical-session.target"];
      wants = ["graphical-session-pre.target"];
      after = ["graphical-session-pre.target"];
    };
  };
}
