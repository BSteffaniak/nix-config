# Auto-discovery overlay for source-built packages
#
# Scans lib/source-builds/configs/*.json and creates a package for each one
# that has buildSystem = "rust" (simple buildRustPackage).
#
# To add a new source-built package, just:
#   1. Add a flake input to flake.nix (flake = false)
#   2. Create a config JSON in lib/source-builds/configs/
#   3. Run: ./scripts/source-build.sh update <name>
#
# No other Nix file edits needed. For complex builds (custom toolchains,
# build phases, etc.), use a standalone overlay file in lib/overlays/ instead.
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    configDir = ../source-builds/configs;
    hashesDir = ../source-builds/hashes;
    cargoVendorPythonPath = ../source-builds/cargo-vendor-sitecustomize;
    lockData = builtins.fromJSON (builtins.readFile ../../flake.lock);

    # Discover all config files
    configFiles = builtins.attrNames (builtins.readDir configDir);
    jsonFiles = builtins.filter (f: builtins.match ".*\\.json" f != null) configFiles;
    projectNames = map (f: builtins.replaceStrings [ ".json" ] [ "" ] f) jsonFiles;

    # Only handle simple builds (rust for now); complex builds use standalone overlays
    isSimpleBuild = config: config.buildSystem == "rust" && !(config ? "complex" && config.complex);

    # Build a package for a single project
    mkProjectPkg =
      final: name:
      let
        configFile = configDir + "/${name}.json";
        hashFile = hashesDir + "/${name}.json";
        config = builtins.fromJSON (builtins.readFile configFile);
      in
      if !isSimpleBuild config then
        # Skip complex builds -- they have their own overlay files
        { }
      else if !builtins.pathExists hashFile then
        builtins.trace "WARNING: ${name} hash file not found. Run: ./scripts/source-build.sh update ${name}"
          { }
      else
        let
          flakeInputName = config.flakeInput;
          src = inputs.${flakeInputName} or null;
        in
        if src == null then
          builtins.trace
            "WARNING: ${name}: flake input '${flakeInputName}' not found in inputs. Add it to flake.nix."
            { }
        else
          let
            hashData = builtins.fromJSON (builtins.readFile hashFile);
            lockedRev = lockData.nodes.${flakeInputName}.locked.rev or "unknown";
            _ =
              if hashData.rev != lockedRev then
                throw ''
                  ${name}: hash file is stale.
                    flake.lock rev: ${lockedRev}
                    hash file rev:  ${hashData.rev}
                  Run: ./scripts/source-build.sh update ${name}
                ''
              else
                null;

            # Optional config fields with defaults
            doCheck = config.doCheck or true;
            cargoBuildFlags = config.cargoBuildFlags or [ ];
            nativeBuildInputs = map (pkgName: final.${pkgName}) (config.nativeBuildInputs or [ ]);
            buildInputs = map (pkgName: final.${pkgName}) (config.buildInputs or [ ]);
            hooksDir = ../source-builds/hooks;
            postInstall =
              if config ? "postInstallFile" then
                builtins.readFile (hooksDir + "/${config.postInstallFile}")
              else
                null;
          in
          {
            ${config.pname} = final.rustPlatform.buildRustPackage (
              {
                pname = config.pname;
                version = "unstable";
                inherit src;
                ${config.hashField} = hashData.${config.hashField};
                inherit doCheck;
                depsExtraArgs = {
                  env.PYTHONPATH = builtins.toString cargoVendorPythonPath;
                };
              }
              // (if cargoBuildFlags != [ ] then { inherit cargoBuildFlags; } else { })
              // (if nativeBuildInputs != [ ] then { inherit nativeBuildInputs; } else { })
              // (if buildInputs != [ ] then { inherit buildInputs; } else { })
              // (if postInstall != null then { inherit postInstall; } else { })
            );
          };
  in
  [
    (final: prev: builtins.foldl' (acc: name: acc // (mkProjectPkg final name)) { } projectNames)
  ]
