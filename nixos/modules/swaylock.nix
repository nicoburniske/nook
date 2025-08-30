{pkgs, ...}: {
  programs.swaylock.package = pkgs.swaylock-effects;
  programs.swaylock = {
    enable = true;

    settings = {
      font-size = 24;
      show-failed-attempts = true;
      indicator = true;

      effect-blur = "7x5";
      effect-vignette = "0.5:0.5";

      clock = true;
      datestr = "%a, %B %e";
      timestr = "%I:%M %p";
    };
  };
}
