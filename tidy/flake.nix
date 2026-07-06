{
  description = "nix-tidy";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
        alejandra = pkgs.runCommand "alejandra-patched-src" {} ''
          cp -R ${
            pkgs.fetchgit {
              url = "https://github.com/kamadorueda/alejandra";
              rev = "8c4a4a572bee519b04e9bb9207e7d993f55ecb4f";
              hash = "sha256-pu6dVB6NrIj90rrqCgJ5pPlBzS76pW4WA6rE1rD1Gp8=";
            }
          } $out
          chmod -R u+w $out
          patch -d $out -p1 < ${./patches/alejandra-format-syntax.patch}
        '';
        vendor = ''
          rm -rf vendor
          cp -R ${alejandra} vendor
          chmod -R u+w vendor
        '';
      in
        f pkgs vendor);
  in {
    packages = forAllSystems (pkgs: vendor: let
      nixTidy = pkgs.rustPlatform.buildRustPackage {
        pname = "nix-tidy";
        version = "0.1.0";
        src = ./.;
        cargoLock = {
          lockFile = ./Cargo.lock;
        };
        postPatch = vendor;
        doCheck = true;
        meta.mainProgram = "nix-tidy";
      };
    in {
      default = nixTidy;
      nix-tidy = nixTidy;
    });
    checks = nixpkgs.lib.genAttrs systems (system: {
      default = self.packages.${system}.default;
      nix-tidy = self.packages.${system}.default;
    });
    devShells = forAllSystems (pkgs: vendor: {
      default = pkgs.mkShell {
        packages = with pkgs; [cargo rustc rust-analyzer rustfmt];
        shellHook = vendor;
      };
    });
  };
}
