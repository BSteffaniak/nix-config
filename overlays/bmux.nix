# bmux builds its Mermaid guest from its own tree; see
# pkgs/source-builds/bmux-mermaid-guest.nix.
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
  mermaidGuest = import ../pkgs/source-builds/bmux-mermaid-guest.nix {
    pkgs = final;
    inherit fetchCargoVendor;
  };
in
if source == null then
  { }
else
  let
    hostPlatform = final.makeRustPlatform {
      cargo = final.rustStable;
      rustc = final.rustStable;
    };
    guest = mermaidGuest.build {
      name = "bmux-mermaid-guest";
      source = mermaidGuest.treeSource source.src;
      hash = source.hashes.guestCargoHash;
      toolchain = final.rustStable;
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
