# Auto-discovery overlay for GitHub release binaries
#
# Scans lib/github-releases/configs/*.json and creates a package for each one.
# To add a new project, just create a config JSON and run:
#   ./scripts/github-release.sh update <name>
#
# No manual Nix file edits needed when adding/removing projects.
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    configDir = ../github-releases/configs;
    versionsDir = ../github-releases/versions;

    # Discover all config files
    configFiles = builtins.attrNames (builtins.readDir configDir);
    jsonFiles = builtins.filter (f: builtins.match ".*\\.json" f != null) configFiles;
    projectNames = map (f: builtins.replaceStrings [ ".json" ] [ "" ] f) jsonFiles;

    # Build a package for a single project
    mkProjectPkg =
      final: name:
      let
        configFile = configDir + "/${name}.json";
        versionFile = versionsDir + "/${name}.json";
      in
      if builtins.pathExists versionFile then
        let
          mkGitHubRelease = import ../github-releases/mkGitHubRelease.nix { pkgs = final; };
          config = builtins.fromJSON (builtins.readFile configFile);
          versionData = builtins.fromJSON (builtins.readFile versionFile);
        in
        {
          ${config.pname} = mkGitHubRelease { inherit config versionData; };
        }
      else
        builtins.trace
          "WARNING: version file not found for '${name}'. Run: ./scripts/github-release.sh update ${name}"
          { };
  in
  [
    (final: prev: builtins.foldl' (acc: name: acc // (mkProjectPkg final name)) { } projectNames)
  ]
