# Overlay for ra-multiplex
# Enable with: enableRaMultiplex = true
#
# Dependency hash managed by: ./scripts/source-build.sh update ra-multiplex
# Hash file: lib/source-builds/hashes/ra-multiplex.json
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    ra-multiplex-src = inputs.ra-multiplex or null;

    hashFile = ../source-builds/hashes/ra-multiplex.json;
    hasHashFile = builtins.pathExists hashFile;

    lockData = builtins.fromJSON (builtins.readFile ../../flake.lock);
    lockedRev = lockData.nodes.ra-multiplex.locked.rev or "unknown";
  in
  if ra-multiplex-src == null then
    [ ]
  else if !hasHashFile then
    builtins.trace
      "WARNING: ra-multiplex hash file not found. Run: ./scripts/source-build.sh update ra-multiplex"
      [ ]
  else
    let
      hashData = builtins.fromJSON (builtins.readFile hashFile);
      _ =
        if hashData.rev != lockedRev then
          throw ''
            ra-multiplex: hash file is stale.
              flake.lock rev: ${lockedRev}
              hash file rev:  ${hashData.rev}
            Run: ./scripts/source-build.sh update ra-multiplex
          ''
        else
          null;
    in
    [
      (final: prev: {
        ra-multiplex-latest = final.rustPlatform.buildRustPackage {
          pname = "ra-multiplex";
          version = "unstable";

          src = ra-multiplex-src;

          cargoHash = hashData.cargoHash;
        };
      })
    ]
