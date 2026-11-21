# BMUX's Mermaid renderer embeds a wasm "guest" that its build.rs normally
# compiles with a nested, networked `cargo build`. That cannot work in the Nix
# sandbox, so packagers build the guest here and hand it over through
# BMUX_MERMAID_WASM_PATH.
#
# Every consumer builds the guest from the exact `bmux_mermaid_render` and
# `bmux_fonts` sources it locks itself, so the guest can never drift from the
# renderer a package embeds, and no flake pins have to be kept in step.
#
#   vendoredSource cargoDeps   guest inputs from a consumer's vendored crates
#   treeSource src             guest inputs from a bmux source checkout
#   vendor { name, source, hash }   offline deps for the guest's own Cargo.lock
#   build  { name, source, hash, toolchain }   the guest (lib/mermaid.wasm)
#
# `vendor` needs no custom toolchain, so scripts/source-build.sh can use it to
# compute hashes against plain nixpkgs.
{
  pkgs,
  fetchCargoVendor,
}:
let
  # Mirrors guest_build::prepare in bmux's packages/mermaid-render.
  assemble = locate: ''
    ${locate}
    mkdir -p "$out/src"
    cp "$render/guest/Cargo.toml.in" "$out/Cargo.toml"
    cp "$render/guest/Cargo.lock.in" "$out/Cargo.lock"
    cp "$render/guest/src/lib.rs" "$out/src/lib.rs"
    cp "$fonts/assets/diagram/BmuxDiagram-Regular.ttf" "$out/BmuxDiagram-Regular.ttf"
  '';
in
rec {
  vendoredSource =
    cargoDeps:
    pkgs.runCommand "bmux-mermaid-guest-source" { } (assemble ''
      # Exactly one renderer/font crate must be vendored, or the guest is ambiguous.
      only() {
        local matches
        matches=$(find ${cargoDeps} -mindepth 1 -maxdepth 2 -type d -name "$1-*")
        if [ "$(printf '%s\n' "$matches" | grep -c .)" != 1 ]; then
          echo "expected exactly one vendored $1 crate in ${cargoDeps}, found:" >&2
          printf '%s\n' "$matches" >&2
          exit 1
        fi
        printf '%s\n' "$matches"
      }
      render=$(only bmux_mermaid_render)
      fonts=$(only bmux_fonts)
    '');

  treeSource =
    src:
    pkgs.runCommand "bmux-mermaid-guest-source" { } (assemble ''
      render=${src}/packages/mermaid-render
      fonts=${src}/packages/fonts
    '');

  vendor =
    {
      name,
      source,
      hash,
    }:
    fetchCargoVendor {
      inherit name hash;
      src = source;
      env.PYTHONPATH = "${./cargo-vendor-sitecustomize}";
    };

  build =
    {
      name,
      source,
      hash,
      toolchain,
    }:
    let
      guestToolchain = toolchain.override { targets = [ "wasm32-unknown-unknown" ]; };
      guestPlatform = pkgs.makeRustPlatform {
        cargo = guestToolchain;
        rustc = guestToolchain;
      };
    in
    guestPlatform.buildRustPackage {
      pname = name;
      version = "unstable";
      src = source;
      cargoDeps = vendor { inherit name source hash; };
      # The derivation runs native Cargo but deliberately emits a portable module.
      buildPhase = ''
        runHook preBuild
        # Keep panic locations independent of Darwin's randomized build root.
        export RUSTFLAGS="''${RUSTFLAGS-} --remap-path-prefix=$NIX_BUILD_TOP=/build"
        cargo build --frozen --release --target wasm32-unknown-unknown
        runHook postBuild
      '';
      doCheck = false;
      installPhase = ''
        mkdir -p "$out/lib"
        cp target/wasm32-unknown-unknown/release/bmux_mermaid_guest.wasm "$out/lib/mermaid.wasm"
      '';
    };
}
