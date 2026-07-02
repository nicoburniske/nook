{...}: {
  flake.mod.nixos.docker = {host, ...}: {
    virtualisation.docker = {
      enable = false;

      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    users.users.${host.user}.linger = true;
  };
}
