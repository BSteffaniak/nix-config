# Rust toolchains via oxalica/rust-overlay.
#
# Exposes:
#   rustStable / rustNightly      - fixed toolchains with common extensions
#   mkRustStable / mkRustNightly  - toolchain builders with configurable rust-src
#   mkCargoWrapper / mkRustcWrapper - `cargo +nightly` style dispatch wrappers
{ inputs }:
[
  (import inputs.rust-overlay)

  (final: prev: {
    mkRustExtensions =
      {
        includeRustSrc ? true,
        extraExtensions ? [ ],
      }:
      (if includeRustSrc then [ "rust-src" ] else [ ]) ++ extraExtensions;

    rustStable = final.rust-bin.stable.latest.default.override {
      extensions = [
        "rust-src"
        "rust-analyzer"
        "clippy"
        "rustfmt"
      ];
    };

    rustNightly = final.rust-bin.nightly.latest.default.override {
      extensions = [
        "rust-src"
        "clippy"
        "rustfmt"
        "llvm-tools-preview"
      ];
    };

    mkRustStable =
      {
        includeRustSrc ? true,
      }:
      final.rust-bin.stable.latest.default.override {
        extensions = final.mkRustExtensions {
          inherit includeRustSrc;
          extraExtensions = [
            "rust-analyzer"
            "clippy"
            "rustfmt"
          ];
        };
      };

    mkRustNightly =
      {
        includeRustSrc ? true,
      }:
      final.rust-bin.nightly.latest.default.override {
        extensions = final.mkRustExtensions {
          inherit includeRustSrc;
          extraExtensions = [
            "clippy"
            "rustfmt"
            "llvm-tools-preview"
          ];
        };
      };
  })

  # Wrapper scripts supporting `cargo +nightly` / `rustc +stable` dispatch.
  # Only installed when both stable and nightly are enabled.
  (
    final: prev:
    let
      mkToolchainWrapper =
        tool:
        {
          rustStable ? final.rustStable,
          rustNightly ? final.rustNightly,
        }:
        final.writeShellScriptBin tool ''
          case "$1" in
            +nightly)
              shift
              exec ${rustNightly}/bin/${tool} "$@"
              ;;
            +stable)
              shift
              exec ${rustStable}/bin/${tool} "$@"
              ;;
            *)
              exec ${rustStable}/bin/${tool} "$@"
              ;;
          esac
        '';
    in
    {
      mkCargoWrapper = mkToolchainWrapper "cargo";
      mkRustcWrapper = mkToolchainWrapper "rustc";

      cargo-wrapped = final.mkCargoWrapper { };
      rustc-wrapped = final.mkRustcWrapper { };
    }
  )
]
