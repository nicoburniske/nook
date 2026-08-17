{
  darwinModules.hammerspoon = {
    config,
    pkgs,
    ...
  }: let
    hammerspoonLauncher = pkgs.writeShellScriptBin "seni-hammerspoon-launch" ''
      set -eu
      /usr/bin/defaults write org.hammerspoon.Hammerspoon MJConfigFile "$HOME/.config/hammerspoon/init.lua"
      exec /Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon -n
    '';
  in {
    environment.systemPackages = [
      hammerspoonLauncher
    ];

    launchd.agents.hammerspoon = {
      path = [config.environment.systemPath];
      serviceConfig = {
        ProgramArguments = [
          "${hammerspoonLauncher}/bin/seni-hammerspoon-launch"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/hammerspoon.out.log";
        StandardErrorPath = "/tmp/hammerspoon.err.log";
      };
    };
  };

  homeModules.hammerspoon = {
    host,
    pkgs,
    ...
  }: {
    file.config."hammerspoon".value = pkgs.mkOutOfStoreSymlink "${host.flakeRoot}/modules/hammerspoon/config";
    effect.hammerspoon = {
      on = ["theme"];
      exec = [
        "/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"
        "-A"
        "-c"
        "hs.reload()"
      ];
      ignoreFailure = true;
    };
  };
}
