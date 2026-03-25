# Overlay for worktree-setup
# Enable with: enableWorktreeSetup = true
#
# Dependency hash managed by: ./scripts/source-build.sh update worktree-setup
# Hash file: lib/source-builds/hashes/worktree-setup.json
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    worktree-setup-src = inputs.worktree-setup or null;

    hashFile = ../source-builds/hashes/worktree-setup.json;
    hasHashFile = builtins.pathExists hashFile;

    lockData = builtins.fromJSON (builtins.readFile ../../flake.lock);
    lockedRev = lockData.nodes."worktree-setup-src".locked.rev or "unknown";
  in
  if worktree-setup-src == null then
    [ ]
  else if !hasHashFile then
    builtins.trace
      "WARNING: worktree-setup hash file not found. Run: ./scripts/source-build.sh update worktree-setup"
      [ ]
  else
    let
      hashData = builtins.fromJSON (builtins.readFile hashFile);
      _ =
        if hashData.rev != lockedRev then
          throw ''
            worktree-setup: hash file is stale.
              flake.lock rev: ${lockedRev}
              hash file rev:  ${hashData.rev}
            Run: ./scripts/source-build.sh update worktree-setup
          ''
        else
          null;
    in
    [
      (final: prev: {
        worktree-setup = final.rustPlatform.buildRustPackage {
          pname = "worktree-setup";
          version = "unstable";

          src = worktree-setup-src;

          cargoHash = hashData.cargoHash;

          cargoBuildFlags = [
            "--package"
            "worktree-setup"
          ];

          doCheck = false;
        };
      })
    ]
