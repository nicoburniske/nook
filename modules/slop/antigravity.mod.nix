{
  commonModules.antigravity = {pkgs, ...}: {
    nixpkgs.allowedUnfreePackages = [pkgs.antigravity-cli];
  };

  homeModules.antigravity = {pkgs, ...}: {
    packages = [pkgs.antigravity-cli];
  };
}
