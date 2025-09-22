{
  pkgs,
  inputs,
  ...
}: let
  pkgs-master = import inputs.nixpkgs-master {
    system = pkgs.system;
  };
in {
  programs.opencode = {
    enable = true;
    package = pkgs-master.opencode;
    settings = {
      autoupdate = false;
    };
  };
}
