# The portable Mermaid guest is an explicit, offline build dependency.
{ inputs }:
final: prev:
let
  source = import ../lib/locked-source.nix { inherit (prev) lib; } {
    inherit inputs;
    inputName = "bmux-src";
    hashFile = ../pkgs/source-builds/hashes/bmux.json;
    updateCommand = "./scripts/source-build.sh update bmux";
  };
  fetchCargoVendor = import ../pkgs/source-builds/fetch-cargo-vendor.nix {
    pkgs = final;
    rustPlatform = final.makeRustPlatform {
      cargo = final.rustStable;
      rustc = final.rustStable;
    };
  };
in
if source == null then
  { }
else
  let
    guestToolchain = final.rustStable.override {
      targets = [ "wasm32-unknown-unknown" ];
    };
    guestPlatform = final.makeRustPlatform {
      cargo = guestToolchain;
      rustc = guestToolchain;
    };
    hostPlatform = final.makeRustPlatform {
      cargo = final.rustStable;
      rustc = final.rustStable;
    };
    guestSource = final.runCommand "bmux-mermaid-guest-source" { } ''
      mkdir -p "$out/src"
      cp ${source.src}/packages/mermaid-render/guest/Cargo.toml.in "$out/Cargo.toml"
      cp ${source.src}/packages/mermaid-render/guest/Cargo.lock.in "$out/Cargo.lock"
      cp ${source.src}/packages/mermaid-render/guest/src/lib.rs "$out/src/lib.rs"
      cp ${source.src}/packages/fonts/assets/diagram/BmuxDiagram-Regular.ttf "$out/BmuxDiagram-Regular.ttf"
    '';
    guest = guestPlatform.buildRustPackage {
      pname = "bmux-mermaid-guest";
      version = "unstable";
      src = guestSource;
      cargoDeps = fetchCargoVendor {
        name = "bmux-mermaid-guest";
        src = guestSource;
        hash = source.hashes.guestCargoHash;
        env.PYTHONPATH = "${../pkgs/source-builds/cargo-vendor-sitecustomize}";
      };
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
  in
  {
    bmux = (hostPlatform.buildRustPackage.override { inherit fetchCargoVendor; }) {
      pname = "bmux";
      version = "unstable";
      inherit (source) src;
      cargoHash = source.hashes.cargoHash;
      depsExtraArgs.env.PYTHONPATH = "${../pkgs/source-builds/cargo-vendor-sitecustomize}";
      BMUX_MERMAID_WASM_PATH = "${guest}/lib/mermaid.wasm";
      cargoBuildFlags = [
        "--package"
        "bmux_cli"
      ];
      doCheck = false;
      passthru.mermaidGuest = guest;
    };
  }
