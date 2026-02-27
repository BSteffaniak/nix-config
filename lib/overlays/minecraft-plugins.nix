# Auto-discovery overlay for Minecraft plugin JARs
#
# Scans lib/minecraft-plugins/configs/*.json and creates a fetchurl derivation
# for each one under pkgs.minecraftPlugins.<name>.
#
# To add a new plugin, create a config JSON and run:
#   ./scripts/minecraft-plugin.sh update <name>
#
# No manual Nix file edits needed when adding/removing plugins.
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    configDir = ../minecraft-plugins/configs;
    versionsDir = ../minecraft-plugins/versions;

    # Discover all config files
    configFiles = builtins.attrNames (builtins.readDir configDir);
    jsonFiles = builtins.filter (f: builtins.match ".*\\.json" f != null) configFiles;
    pluginNames = map (f: builtins.replaceStrings [ ".json" ] [ "" ] f) jsonFiles;

    # Build a plugin derivation for a single plugin
    mkPluginPkg =
      final: name:
      let
        configFile = configDir + "/${name}.json";
        versionFile = versionsDir + "/${name}.json";
      in
      if builtins.pathExists versionFile then
        let
          mkMinecraftPlugin = import ../minecraft-plugins/mkMinecraftPlugin.nix { pkgs = final; };
          config = builtins.fromJSON (builtins.readFile configFile);
          versionData = builtins.fromJSON (builtins.readFile versionFile);
        in
        {
          ${config.pname} = mkMinecraftPlugin { inherit config versionData; };
        }
      else
        builtins.trace
          "WARNING: version file not found for Minecraft plugin '${name}'. Run: ./scripts/minecraft-plugin.sh update ${name}"
          { };
  in
  [
    (final: prev: {
      minecraftPlugins =
        (prev.minecraftPlugins or { })
        // builtins.foldl' (acc: name: acc // (mkPluginPkg final name)) { } pluginNames;
    })
  ]
