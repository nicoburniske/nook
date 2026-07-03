# DO-NOT-EDIT: file was auto-generated using 'just gen'
{
  description = "dendritic multi host nix config";
  inputs = {
    agenix = {
      inputs = {
        darwin.follows = "";
        home-manager.follows = "";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:ryantm/agenix";
    };
    apple-silicon = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nixos-apple-silicon";
    };
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    helium-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:schembriaiden/helium-browser-nix-flake";
    };
    helix-steel = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:mattwparas/helix/steel-event-system";
    };
    homebrew-cask = {
      flake = false;
      url = "github:homebrew/homebrew-cask";
    };
    homebrew-core = {
      flake = false;
      url = "github:homebrew/homebrew-core";
    };
    niri = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:niri-wm/niri";
    };
    nix-darwin = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:LnL7/nix-darwin";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-tidy = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "path:./tidy";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    noctalia = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:noctalia-dev/noctalia";
    };
    self.lfs = true;
    sumi = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "path:./sumi";
    };
  };
  nixConfig = {experimental-features = ["nix-command" "flakes" "pipe-operators"];};
  outputs = inputs: import ./flake.output.nix inputs;
}
