{...}: {
  flake.modules.darwin.hammerspoon = {
    config,
    inputs,
    pkgs,
    ...
  }: let
    themeSwitch = import (inputs.self + "/common/theme-switch.nix") {inherit pkgs;};
  in {
    environment.systemPackages = [themeSwitch];

    sumi.file = {
      ".hammerspoon".source = config.lib.sumi.mkOutOfStoreSymlink "${config.lib.sumi.paths.flakeRootOrErr}/modules/hammerspoon/config";
    };

    launchd.user.agents.hammerspoon = {
      path = [config.environment.systemPath];
      serviceConfig = {
        ProgramArguments = [
          "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon"
          "-n"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/hammerspoon.out.log";
        StandardErrorPath = "/tmp/hammerspoon.err.log";
      };
    };

    sumi.program.hammerspoon.reload = ''
      /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -A -c "hs.reload()"
    '';
  };
}
