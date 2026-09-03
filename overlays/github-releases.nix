# Auto-discovery overlay for GitHub release binaries.
#
# Scans pkgs/github-releases/configs/*.json and creates a package for each.
# To add a project: ./scripts/github-release.sh add, then
# ./scripts/github-release.sh update <name>.
{ inputs }:
final: prev:
let
  readJsonDir = import ../lib/read-json-dir.nix;
  configs = readJsonDir ../pkgs/github-releases/configs;
  versionsDir = ../pkgs/github-releases/versions;
  mkGitHubRelease = import ../pkgs/github-releases/mk-github-release.nix { pkgs = final; };

  mkPackage =
    name: config:
    let
      versionFile = versionsDir + "/${name}.json";
    in
    if builtins.pathExists versionFile then
      {
        ${config.pname} = mkGitHubRelease {
          inherit config;
          versionData = builtins.fromJSON (builtins.readFile versionFile);
        };
      }
    else
      builtins.trace
        "WARNING: version file not found for '${name}'. Run: ./scripts/github-release.sh update ${name}"
        { };
in
prev.lib.concatMapAttrs mkPackage configs
