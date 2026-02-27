# mkMinecraftPlugin - Generic builder for Minecraft plugin JARs
#
# Takes a per-plugin config and auto-generated version data, and produces
# a fetchurl derivation for the plugin JAR.
#
# Unlike mkGitHubRelease (which handles platform-specific binaries),
# Minecraft plugins are platform-independent JAR files.
#
# Usage in an overlay:
#   let
#     mkMinecraftPlugin = import ../minecraft-plugins/mkMinecraftPlugin.nix { pkgs = final; };
#     config = builtins.fromJSON (builtins.readFile ../minecraft-plugins/configs/foo.json);
#     versionData = builtins.fromJSON (builtins.readFile ../minecraft-plugins/versions/foo.json);
#   in
#   mkMinecraftPlugin { inherit config versionData; }
#
{ pkgs }:

{ config, versionData }:

pkgs.fetchurl {
  name = "${config.pname}-${versionData.version}.jar";
  url = versionData.url;
  sha256 = versionData.sha256;
}
