{ pkgs, lib, rustPlatform, fetchFromGitHub }:
with pkgs;
rustPlatform.buildRustPackage rec {
  pname = "deepcool-digital-linux";
  version = "0.6.0-alpha";

  src = fetchFromGitHub {
    owner = "Nortank12";
    repo = "deepcool-digital-linux";
    rev = "v${version}";
    hash = "sha256-/nNcUC73Hffk13zhSXY6CuVPwn11I+sKhSnlxHV7HDE="; # Replace with the correct hash
  };
  cargoHash = lib.fakeHash;
  postPatch = ''
      cp ${./Cargo.lock} Cargo.lock
    '';
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ systemd ];
}
