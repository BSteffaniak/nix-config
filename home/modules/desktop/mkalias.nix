# macOS application alias management for home-manager packages
#
# On macOS, Nix packages with .app bundles end up in the Nix store
# which Spotlight and Finder cannot index. This module creates Finder
# aliases (via mkalias) directly in /Applications/ so that GUI apps
# installed through home-manager are fully discoverable in Spotlight,
# Launchpad, and Dock.
#
# A manifest file (~/.local/state/hm-mkalias-apps.txt) tracks which
# aliases were created so they can be cleaned up on subsequent runs
# without affecting other apps in /Applications/.
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

let
  cfg = config.myConfig.desktop.mkalias;

  # Build a case-statement pattern that lets us `continue` the alias
  # loop for any app in the exclusion list. Each basename is escaped
  # individually to tolerate unusual characters in a .app name.
  skipCase =
    if cfg.excludeApps == [ ] then
      ""
    else
      ''
        case "$app_name" in
          ${lib.concatMapStringsSep " | " lib.escapeShellArg cfg.excludeApps})
            continue
            ;;
        esac
      '';
in
{
  options.myConfig.desktop.mkalias = {
    enable = mkEnableOption "macOS Finder aliases for home-manager apps";

    excludeApps = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "Sledge.app" ];
      description = ''
        App basenames (e.g. `"Sledge.app"`) to skip when creating
        Finder aliases. Use this for home-manager packages that self-
        install to `/Applications/` via their own activation script,
        where a Finder alias would conflict with the real bundle on
        subsequent rebuilds.
      '';
    };
  };

  config = mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    home.activation.aliasHomeManagerApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      manifest="''${XDG_STATE_HOME:-$HOME/.local/state}/hm-mkalias-apps.txt"

      # Clean up aliases from previous run
      if [ -f "$manifest" ]; then
        while IFS= read -r old_alias; do
          if [ -n "$old_alias" ] && [ -f "$old_alias" ]; then
            run rm -f "$old_alias"
          fi
        done < "$manifest"
      fi

      # Clean up old subfolder from previous approach
      if [ -d "/Applications/Home Manager Apps" ]; then
        run rm -rf "/Applications/Home Manager Apps"
      fi

      # Create new aliases directly in /Applications/
      : > "$manifest"
      hm_apps="${config.home.path}/Applications"
      if [ -d "$hm_apps" ]; then
        find "$hm_apps" -maxdepth 1 -name "*.app" -type l -exec readlink '{}' + | while read -r src; do
          app_name=$(basename "$src")
          ${skipCase}
          target="/Applications/$app_name"
          run ${pkgs.mkalias}/bin/mkalias "$src" "$target"
          echo "$target" >> "$manifest"
        done
      fi
    '';
  };
}
