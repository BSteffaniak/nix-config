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
  allNames = map (f: removeSuffix ".json" f) jsonPermissionFiles;

  # Base names are those that don't end in -restricted or -yolo
  isVariant = name: hasSuffix "-restricted" name || hasSuffix "-yolo" name;
  baseNames = builtins.filter (name: !(isVariant name)) allNames;

  # Resolve each base name to the correct variant file
  # Priority: yolo > restricted > default
  resolvePermissionFile =
    name:
    if builtins.elem name cfg.permissions.yolo then
      "${name}-yolo"
    else if builtins.elem name cfg.permissions.restricted then
      "${name}-restricted"
    else
      name;

  # Filter based on autoDiscover / include / exclude
  discoveredNames =
    let
      base = if cfg.permissions.autoDiscover then baseNames else cfg.permissions.include;
    in
    builtins.filter (name: !(builtins.elem name cfg.permissions.exclude)) base;

  # Resolve to actual file names (applying restricted/yolo variants)
  resolvedNames = map resolvePermissionFile discoveredNames;

  # Read and parse each active permission file
  permissionConfigs = map (
    name: builtins.fromJSON (builtins.readFile (permissionsDir + "/${name}.json"))
  ) (builtins.sort (a: b: a < b) resolvedNames);

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

      restricted = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Use <name>-restricted.json instead of <name>.json for these programs (denies all write ops in build agent)";
      };

      yolo = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Use <name>-yolo.json instead of <name>.json for these programs (no build agent restrictions)";
      };
    };
  };

  config = mkIf cfg.enable {
    xdg.configFile."opencode/opencode.json".text = builtins.toJSON mergedConfig;

    # Global skills (auto-discovered by OpenCode from ~/.config/opencode/skills/)
    xdg.configFile."opencode/skills/_shared" = {
      source = ../../../configs/opencode/skills/_shared;
      recursive = true;
    };
    xdg.configFile."opencode/skills/commit-message" = {
      source = ../../../configs/opencode/skills/commit-message;
      recursive = true;
    };
    xdg.configFile."opencode/skills/commit-message-write" = {
      source = ../../../configs/opencode/skills/commit-message-write;
      recursive = true;
    };
    xdg.configFile."opencode/skills/commit-message-staged" = {
      source = ../../../configs/opencode/skills/commit-message-staged;
      recursive = true;
    };
    xdg.configFile."opencode/skills/commit-message-staged-write" = {
      source = ../../../configs/opencode/skills/commit-message-staged-write;
      recursive = true;
    };
    xdg.configFile."opencode/skills/session-history" = {
      source = ../../../configs/opencode/skills/session-history;
      recursive = true;
    };
  };
}
