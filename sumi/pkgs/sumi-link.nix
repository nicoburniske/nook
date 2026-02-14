{rustPlatform}:
rustPlatform.buildRustPackage {
  pname = "sumi-link";
  version = "0.1.0";

  src = ../sumi-link;
  cargoLock.lockFile = ../sumi-link/Cargo.lock;
}
