{...}: {
  flake.modules.nixos.steam = {pkgs, ...}: let
    # hack for startup crash
    # https://github.com/NixOS/nixpkgs/issues/324875#issuecomment-2308355036
    steam = pkgs.steam.override (prev: {
      extraPreBwrapCmds =
        (prev.extraPreBwrapCmds or "")
        + ''
          ${pkgs.systemd}/bin/systemctl --user restart pipewire || true
        '';
    });
  in {
    programs.steam = {
      enable = true;
      package = steam;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
  };
}
