{...}: {
  flake.modules.nixos.steam = {pkgs, ...}: let
    # Retry after restarting PipeWire if Steam exits non-zero on startup:
    # https://github.com/NixOS/nixpkgs/issues/324875#issuecomment-2308355036
    steam = pkgs.steam.override (prev: {
      extraProfile =
        (prev.extraProfile or "")
        + ''
          steam() {
            if command steam "$@"; then
              return 0
            fi

            ${pkgs.systemd}/bin/systemctl --user restart pipewire || true
            exec steam "$@"
          }

          export -f steam
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
