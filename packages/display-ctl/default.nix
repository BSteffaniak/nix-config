{
  pkgs,
  lib,
}:

# display-ctl: A small Swift CLI that toggles auto-brightness and True Tone
# on macOS using private CoreBrightness/DisplayServices framework APIs.
#
# These APIs are the same ones used by System Settings and apps like Lunar.
# Since they require Apple's private frameworks (only available on the host
# macOS system), we build with the system Swift compiler via impure derivation.
pkgs.stdenv.mkDerivation {
  pname = "display-ctl";
  version = "0.1.0";

  src = ./.;

  # No Nix-provided build inputs needed — we use the host system's
  # Swift compiler and frameworks directly.
  nativeBuildInputs = [ ];

  # Use the system swiftc from Command Line Tools / Xcode.
  # The Nix sandbox doesn't have access to private frameworks,
  # so we need to build impurely.
  buildPhase = ''
    /Library/Developer/CommandLineTools/usr/bin/swiftc \
      -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
      -O \
      -o display-ctl \
      -F /System/Library/PrivateFrameworks \
      -framework CoreBrightness \
      -framework DisplayServices \
      -framework ApplicationServices \
      -framework Foundation \
      main.swift
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp display-ctl $out/bin/
  '';

  # This derivation must build impurely since it needs access to:
  # 1. The system Swift compiler (/Library/Developer/CommandLineTools)
  # 2. Apple private frameworks (/System/Library/PrivateFrameworks)
  __noChroot = true;

  meta = with lib; {
    description = "CLI tool to toggle auto-brightness and True Tone on macOS";
    license = licenses.mit;
    platforms = platforms.darwin;
    mainProgram = "display-ctl";
  };
}
