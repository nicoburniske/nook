{rustPlatform}:
rustPlatform.buildRustPackage {
  pname = "sumi";
  version = "0.1.0";

  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
}
