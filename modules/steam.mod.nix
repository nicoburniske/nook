{
  nixosModules.steam = {pkgs, ...}: let
    gamescopeProfiles = {
      "2k" = ["-W" "2560" "-H" "1440" "-w" "2560" "-h" "1440" "-r" "165" "-f" "--hdr-enabled" "--hdr-debug-force-output"];
      "4k" = ["-W" "5120" "-H" "2880" "-w" "3840" "-h" "2160" "-r" "165" "-f" "--hdr-enabled" "--hdr-debug-force-output"];
      "5k" = ["-W" "5120" "-H" "2880" "-w" "5120" "-h" "2880" "-r" "165" "-f" "--hdr-enabled" "--hdr-debug-force-output"];
    };
    gamescopeWrapper = pkgs.writeNuScriptBin "gs" {
      runtimeInputs = [pkgs.gamescope];
      source = ''
        def --wrapped main [profile: string, ...argv: string] {
          let base_args = (${builtins.toJSON gamescopeProfiles} | get $profile)
          let sep = ($argv | enumerate | where item == "--" | get index | first | default ($argv | length))
          let gamescope_args = ($argv | take $sep)
          let game_args = ($argv | skip ($sep + 1))
          let ld_preload = ($env.LD_PRELOAD? | default "")
          ^env -u LD_PRELOAD gamescope ...$base_args ...$gamescope_args -- env $"LD_PRELOAD=($ld_preload)" ENABLE_GAMESCOPE_WSI=1 DXVK_HDR=1 PROTON_ENABLE_HDR=1 ...$game_args
        }
      '';
    };
  in {
    nixpkgs.allowedUnfreePackages = with pkgs; [
      steam
      steam-unwrapped
    ];

    programs = {
      # https://github.com/NixOS/nixpkgs/issues/324875#issuecomment-2308355036
      # systemctl --user restart pipewire
      steam = {
        enable = true;
        extest.enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        extraPackages = [
          pkgs.hidapi
          pkgs.zlib
        ];
      };
      gamescope = {
        enable = true;
        enableWsi = true;
        capSysNice = false;
      };
    };

    environment.systemPackages = with pkgs; [
      gamescopeWrapper
      hidapi
      mangohud
    ];

    compositor.niri.config = [
      {
        window-rule = [
          {match."app-id" = "^steam$";}
          {exclude.title = "^Steam Input On-screen Keyboard$";}
          {open-on-workspace = "5";}
        ];
      }
      {
        window-rule = [
          {
            match = {
              app-id = "^steam$";
              title = "^Steam Input On-screen Keyboard$";
            };
          }
          {open-focused = false;}
          {open-floating = true;}
          {min-width = 1280;}
          {max-width = 1280;}
          {min-height = 360;}
          {max-height = 360;}
          {
            default-floating-position = {
              x = 0;
              y = 0;
              relative-to = "bottom";
            };
          }
        ];
      }
      {
        window-rule = {
          match."app-id" = "^steam_app_[0-9]+$";
          open-on-workspace = "5";
          open-fullscreen = true;
        };
      }
      {
        window-rule = [
          {match."app-id" = "^gamescope$";}
          {
            match = {
              app-id = "^$";
              title = "^Gamescope$";
            };
          }
          {open-on-workspace = "5";}
          {open-fullscreen = true;}
        ];
      }
    ];

    services.udev.extraRules = ''
      # Steam Controller / Triton firmware updater bootloader access.
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="28de", MODE="0666", TAG+="uaccess"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="28de", MODE="0666", TAG+="uaccess"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="28de", MODE="0666", TAG+="uaccess"
    '';
  };
}
