# Overlay for tone-clone
# Enable with: enableToneClone = true
#
# Dependency hash managed by: ./scripts/source-build.sh update tone-clone
# Hash file: lib/source-builds/hashes/tone-clone.json
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    tone-clone-src = inputs.tone-clone or null;

    hashFile = ../source-builds/hashes/tone-clone.json;
    hasHashFile = builtins.pathExists hashFile;

    lockData = builtins.fromJSON (builtins.readFile ../../flake.lock);
    lockedRev = lockData.nodes."tone-clone-src".locked.rev or "unknown";
  in
  if tone-clone-src == null then
    [ ]
  else if !hasHashFile then
    builtins.trace
      "WARNING: tone-clone hash file not found. Run: ./scripts/source-build.sh update tone-clone"
      [ ]
  else
    let
      hashData = builtins.fromJSON (builtins.readFile hashFile);
      _ =
        if hashData.rev != lockedRev then
          throw ''
            tone-clone: hash file is stale.
              flake.lock rev: ${lockedRev}
              hash file rev:  ${hashData.rev}
            Run: ./scripts/source-build.sh update tone-clone
          ''
        else
          null;
    in
    [
      (final: prev: {
        tone-clone = final.rustPlatform.buildRustPackage {
          pname = "tone-clone";
          version = "unstable";

          src = tone-clone-src;

          cargoHash = hashData.cargoHash;
        };
      })
    ]
