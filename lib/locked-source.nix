# Resolve a non-flake input pinned in flake.lock together with a committed
# hash file, throwing if the hash file is stale.
#
#   lockedSource {
#     inputs;                    # flake inputs
#     inputName = "foo-src";     # name in flake.nix / flake.lock
#     hashFile = ./hashes/foo.json;
#     updateCommand = "./scripts/source-build.sh update foo";
#   }
#   => null                       when the input or hash file is missing (with a trace warning)
#   => { src; rev; shortRev; ref; narHash; hashes; }
{ lib }:
let
  lockData = builtins.fromJSON (builtins.readFile ../flake.lock);
in
{
  inputs,
  inputName,
  hashFile,
  updateCommand,
}:
let
  input = inputs.${inputName} or null;
  node = lockData.nodes.${inputName} or { };
  rev = node.locked.rev or "unknown";
in
if input == null then
  builtins.trace "WARNING: flake input '${inputName}' not found. Add it to flake.nix." null
else if !builtins.pathExists hashFile then
  builtins.trace "WARNING: hash file ${toString hashFile} not found. Run: ${updateCommand}" null
else
  let
    hashes = builtins.fromJSON (builtins.readFile hashFile);
  in
  if (hashes.rev or null) != rev then
    throw ''
      ${inputName}: hash file is stale.
        flake.lock rev: ${rev}
        hash file rev:  ${hashes.rev or "missing"}
      Run: ${updateCommand}
    ''
  else
    {
      src = input;
      inherit rev hashes;
      shortRev = builtins.substring 0 7 rev;
      ref = node.original.ref or "unknown";
      narHash = node.locked.narHash or "";
    }
