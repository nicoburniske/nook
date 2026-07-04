{
  commonModules.codex = {pkgs, ...}: {
    environment.systemPackages = [pkgs.codex];
  };
}
