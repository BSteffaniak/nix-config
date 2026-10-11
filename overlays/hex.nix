# Keep upstream's Linux build environment; remove the patch when updating past
# the missing PathBuf borrow in the pinned 2.1.25 source.
{ inputs }:
final: prev:
prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "x86_64-linux") {
  hex = inputs.hex.packages.x86_64-linux.default.overrideAttrs (old: {
    # Allow the CLI to wait through systemd's 30s stop + 35s start limits.
    # This avoids premature timeout errors; it does not repair shutdown hangs.
    patches = (old.patches or [ ]) ++ [
      ../pkgs/hex/linux-gguf-path.patch
      ../pkgs/hex/linux-service-timeout.patch
      ../pkgs/hex/linux-right-alt.patch
    ];
  });
}
