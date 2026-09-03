# Auto-discovery overlay for source-built Rust packages.
#
# Scans pkgs/source-builds/configs/*.json and builds each simple
# (buildSystem = "rust", not "complex") entry with buildRustPackage.
#
# To add a package:
#   1. Add a flake input to flake.nix (flake = false)
#   2. Create pkgs/source-builds/configs/<name>.json
#   3. Run: nix flake lock && ./scripts/source-build.sh update <name>
#
# Complex builds set "complex": true and get their own overlay file.
{ inputs }:
final: prev:
let
  lockedSource = import ../lib/locked-source.nix { inherit (prev) lib; };
  readJsonDir = import ../lib/read-json-dir.nix;

  configs = readJsonDir ../pkgs/source-builds/configs;
  hashesDir = ../pkgs/source-builds/hashes;
  hooksDir = ../pkgs/source-builds/hooks;
  cargoVendorPythonPath = ../pkgs/source-builds/cargo-vendor-sitecustomize;

  isSimpleBuild = config: config.buildSystem == "rust" && !(config.complex or false);

  rustPlatformFor =
    toolchain:
    if toolchain == "stable" then
      final.makeRustPlatform {
        cargo = final.rustStable;
        rustc = final.rustStable;
      }
    else if toolchain == "nightly" then
      final.makeRustPlatform {
        cargo = final.rustNightly;
        rustc = final.rustNightly;
      }
    else
      final.rustPlatform;

  mkPackage =
    name: config:
    let
      source = lockedSource {
        inherit inputs;
        inputName = config.flakeInput;
        hashFile = hashesDir + "/${name}.json";
        updateCommand = "./scripts/source-build.sh update ${name}";
      };
      pkgsByName = names: map (n: final.${n}) names;
      cargoBuildFlags = config.cargoBuildFlags or [ ];
      nativeBuildInputs = pkgsByName (config.nativeBuildInputs or [ ]);
      buildInputs = pkgsByName (config.buildInputs or [ ]);
    in
    if source == null then
      { }
    else
      {
        ${config.pname} = (rustPlatformFor (config.rustToolchain or null)).buildRustPackage (
          {
            inherit (config) pname;
            version = "unstable";
            inherit (source) src;
            ${config.hashField} = source.hashes.${config.hashField};
            doCheck = config.doCheck or true;
            depsExtraArgs = {
              env.PYTHONPATH = "${cargoVendorPythonPath}";
            };
          }
          // prev.lib.optionalAttrs (cargoBuildFlags != [ ]) { inherit cargoBuildFlags; }
          // prev.lib.optionalAttrs (nativeBuildInputs != [ ]) { inherit nativeBuildInputs; }
          // prev.lib.optionalAttrs (buildInputs != [ ]) { inherit buildInputs; }
          // prev.lib.optionalAttrs (config ? postInstallFile) {
            postInstall = builtins.readFile (hooksDir + "/${config.postInstallFile}");
          }
          // (config.env or { })
        );
      };
in
prev.lib.concatMapAttrs mkPackage (prev.lib.filterAttrs (_: isSimpleBuild) configs)
