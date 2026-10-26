{
  commonModules.claude = {pkgs, ...}: {
    nixpkgs.allowedUnfreePackages = [pkgs.claude-code];
  };

  homeModules.claude = {pkgs, ...}: {
    packages = [pkgs.claude-code];
    file.home.".claude/CLAUDE.md".value = (import ./instructions.nix).instructions;
  };
}
