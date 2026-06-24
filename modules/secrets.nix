{inputs, ...}: {
  flake.modules.nixos.secrets = {
    lib,
    pkgs,
    ...
  }: {
    imports = [
      inputs.agenix.nixosModules.age
      (lib.mkAliasOptionModule ["secrets"] ["age" "secrets"])
    ];

    age = {
      identityPaths = ["/etc/age/identity.txt"];
      ageBin = "${pkgs.age}/bin/age";
    };

    environment.systemPackages = with pkgs; [
      age
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
