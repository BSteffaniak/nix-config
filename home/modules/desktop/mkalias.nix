# macOS application alias management for home-manager packages
#
# On macOS, Nix packages with .app bundles end up in the Nix store
# which Spotlight and Finder cannot index. This module creates Finder
# aliases (via mkalias) in /Applications/Home Manager Apps/ so that
# GUI apps installed through home-manager are discoverable.
#
# This is the home-manager counterpart to modules/darwin/applications.nix
# which handles the same for environment.systemPackages.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.desktop.mkalias = {
    enable = mkEnableOption "macOS Finder aliases for home-manager apps";
  };

  config = mkIf (config.myConfig.desktop.mkalias.enable && pkgs.stdenv.isDarwin) {
    home.activation.aliasHomeManagerApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      app_folder="/Applications/Home Manager Apps"
      run rm -rf "$app_folder"
      run mkdir -p "$app_folder"
      hm_apps="${config.home.path}/Applications"
      if [ -d "$hm_apps" ]; then
        find "$hm_apps" -maxdepth 1 -name "*.app" -type l | while read -r src; do
          app_name=$(basename "$src")
          run ${pkgs.mkalias}/bin/mkalias "$src" "$app_folder/$app_name"
        done
      fi
    '';
  };
}
