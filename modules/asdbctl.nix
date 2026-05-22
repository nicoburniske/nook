{...}: {
  flake.modules.nixos.asdbctl = {pkgs, ...}: {
    nixpkgs.overlays = [
      (final: prev: {
        asdbctl = prev.asdbctl.overrideAttrs {
          version = "unstable-2026-05-21";

          src = final.fetchFromGitHub {
            owner = "juliuszint";
            repo = "asdbctl";
            rev = "2317e450b34ffd89e2da22abd9cba68c34906f68";
            hash = "sha256-jDflaksnsw55RHMgamfJNRE7GwThQMYfXtLAWbOnoMw=";
          };
        };
      })
    ];

    environment.systemPackages = [
      pkgs.asdbctl
    ];

    services.udev.packages = [
      pkgs.asdbctl
    ];
  };
}
