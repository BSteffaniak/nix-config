{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

with lib;

let
  cfg = config.myConfig.development.opencode;

  # Auto-discover permission files from configs/opencode/permissions/
  permissionsDir = ../../../configs/opencode/permissions;
  allPermissionFiles = builtins.attrNames (builtins.readDir permissionsDir);
  jsonPermissionFiles = builtins.filter (f: hasSuffix ".json" f) allPermissionFiles;
  permissionNames = map (f: removeSuffix ".json" f) jsonPermissionFiles;

  # Filter based on autoDiscover / include / exclude
  activePermissionNames =
    let
      base = if cfg.permissions.autoDiscover then permissionNames else cfg.permissions.include;
    in
    builtins.filter (name: !(builtins.elem name cfg.permissions.exclude)) base;

  # Read and parse each active permission file
  permissionConfigs = map (
    name: builtins.fromJSON (builtins.readFile (permissionsDir + "/${name}.json"))
  ) (builtins.sort (a: b: a < b) activePermissionNames);

  # Read and parse host-specific overrides
  overrideConfigs = map (f: builtins.fromJSON (builtins.readFile f)) cfg.overrides;

  # Merge order: base → permissions (alphabetical) → host overrides (in order)
  baseConfig = builtins.fromJSON (builtins.readFile ../../../configs/opencode/opencode.json);
  mergedConfig = foldl' myLib.deepMerge baseConfig (permissionConfigs ++ overrideConfigs);
in
{
  options.myConfig.development.opencode = {
    enable = mkEnableOption "OpenCode AI assistant configuration";

    overrides = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "List of JSON files to deep-merge over the base config (e.g., host-specific encrypted overrides)";
    };

    permissions = {
      autoDiscover = mkOption {
        type = types.bool;
        default = true;
        description = "Auto-discover and merge all permission files from configs/opencode/permissions/";
      };

      include = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "When autoDiscover is false, explicitly list which permission files to include (without .json)";
      };

      exclude = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Permission files to exclude from auto-discovery (without .json)";
      };
    };
  };

  config = mkIf cfg.enable {
    xdg.configFile."opencode/opencode.json".text = builtins.toJSON mergedConfig;
  };
}
