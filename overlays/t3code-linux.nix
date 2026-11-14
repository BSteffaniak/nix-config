# Adapt the official T3 archive to glibc-based Linux hosts.
{ inputs }:
final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  t3code-nightly = prev.t3code-nightly.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ final.vulkan-loader ];

    # Both native loaders ship musl alternatives. ffi-rs selects its GNU
    # binding on glibc, and koffi tries linux_* before its musl fallback.
    # Remove only those unused alternatives before autoPatchelf scans them.
    preFixup = (old.preFixup or "") + ''
      modules="$out/libexec/t3code-nightly/node_modules"
      rm -rf \
        "$modules/@koromix/koffi-linux-x64/musl_x64" \
        "$modules/@koromix/koffi-linux-arm64/musl_arm64" \
        "$modules/@yuuang/ffi-rs-linux-x64-musl" \
        "$modules/@yuuang/ffi-rs-linux-arm64-musl"
    '';
  });
}
