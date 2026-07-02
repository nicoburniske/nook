{...}: {
  flake.mod.darwin.hammerspoon = {
    config,
    pkgs,
    ...
  }: let
    hammerspoonConfigDir = "${config.lib.sumi.paths.config}/hammerspoon";
    hammerspoonLauncher = pkgs.writeShellScriptBin "sumi-hammerspoon-launch" ''
      set -eu
      /usr/bin/defaults write org.hammerspoon.Hammerspoon MJConfigFile "${hammerspoonConfigDir}/init.lua"
      exec /Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon -n
    '';
  in {
    environment.systemPackages = [
      hammerspoonLauncher
    ];

    sumi.configFile = {
      "hammerspoon".value = config.lib.sumi.mkOutOfStoreSymlink "${config.lib.sumi.paths.flakeRootOrErr}/modules/hammerspoon/config";
    };

    launchd.user.agents.hammerspoon = {
      path = [config.environment.systemPath];
      serviceConfig = {
        ProgramArguments = [
          "${hammerspoonLauncher}/bin/sumi-hammerspoon-launch"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/hammerspoon.out.log";
        StandardErrorPath = "/tmp/hammerspoon.err.log";
      };
    };

    sumi.hook.hammerspoon = {
      watch = ["theme"];
      command = ''
        /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -A -c "hs.reload()"
      '';
    };
  };
}
