{
  flake.mod.nixos.user = {
    host,
    pkgs,
    ...
  }: {
    users.users.${host.user} = {
      isNormalUser = true;
      home = host.homeDirectory;
      extraGroups = [
        "wheel"
        "audio"
        "video"
        "render"
        "input"
        "networkmanager"
        "users"
      ];
      shell = pkgs.zsh;
    };
  };
}
