{inputs, ...}: {
  inputs.agenix = {
    url = "github:ryantm/agenix";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "";
      darwin.follows = "";
    };
  };

  perSystem = {system, ...}: {
    packages.agenix = inputs.agenix.packages.${system}.default;
  };

  nixosModules.secrets = {
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
