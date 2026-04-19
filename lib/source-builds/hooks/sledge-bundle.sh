# postInstall fragment for the sledge source-build.
#
# Runs inside buildRustPackage after `cargo install` has placed the
# sledge binary at $out/bin/sledge. We reshape the output tree so
# $out/Applications/Sledge.app is a valid (unsigned) macOS bundle,
# with $out/bin/sledge preserved as a convenience symlink pointing
# inside the bundle.
#
# Signing happens on the target host during darwin activation; see
# modules/darwin/sledge.nix. The build sandbox has no access to the
# login keychain, so the bundle produced here is intentionally
# unsigned.
#
# We also copy the repo's scripts/ into $out/share/sledge/scripts/
# so darwin activation can invoke setup-signing-identity.sh through
# a stable nix-store path, without needing to reach into the source
# derivation's src attribute.

BINARY="$out/bin/sledge"
BUNDLE_DIR="$out/Applications"

mkdir -p "$BUNDLE_DIR"
bash "$src/scripts/bundle-macos.sh" --no-sign "$BINARY" "$BUNDLE_DIR"

# Replace the cargo-installed binary with a symlink into the bundle so
# `pkgs.sledge` still exposes a working $out/bin/sledge for PATH use.
rm "$BINARY"
ln -s "../Applications/Sledge.app/Contents/MacOS/sledge" "$BINARY"

# Expose the helper scripts at a stable location for darwin activation.
mkdir -p "$out/share/sledge"
cp -r "$src/scripts" "$out/share/sledge/"
