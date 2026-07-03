{
  mod.common.codex = {pkgs, ...}: {
    environment.systemPackages = [pkgs.codex];
  };
}
