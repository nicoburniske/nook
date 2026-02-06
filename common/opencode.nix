{
  pkgs,
  inputs,
  ...
}: {
  programs.opencode = {
    enable = true;
    package = inputs.opencode.packages.${pkgs.system}.opencode;
    settings = {
      autoupdate = false;
      tui = {
        scroll_acceleration = {
          enabled = true;
        };
      };
    };
  };
}
