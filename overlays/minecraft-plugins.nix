# Auto-discovery overlay for Minecraft plugin JARs.
#
# Scans pkgs/minecraft-plugins/configs/*.json and exposes each as
# pkgs.minecraftPlugins.<name>.
{ inputs }:
final: prev:
let
  readJsonDir = import ../lib/read-json-dir.nix;
  configs = readJsonDir ../pkgs/minecraft-plugins/configs;
  versionsDir = ../pkgs/minecraft-plugins/versions;
  mkMinecraftPlugin = import ../pkgs/minecraft-plugins/mk-minecraft-plugin.nix { pkgs = final; };

  mkPlugin =
    name: config:
    let
      versionFile = versionsDir + "/${name}.json";
    in
    if builtins.pathExists versionFile then
      {
        ${config.pname} = mkMinecraftPlugin {
          inherit config;
          versionData = builtins.fromJSON (builtins.readFile versionFile);
        };
      }
    else
      builtins.trace
        "WARNING: version file not found for Minecraft plugin '${name}'. Run: ./scripts/minecraft-plugin.sh update ${name}"
        { };
in
{
  minecraftPlugins = (prev.minecraftPlugins or { }) // prev.lib.concatMapAttrs mkPlugin configs;
}
