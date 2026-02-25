{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.development.opencode;

  # Deep merge two attrsets recursively. At every level:
  # - If both sides have an attrset for the same key, recurse and merge
  # - Otherwise, the right (override) value wins
  # This ensures e.g. agent.plan.permission.bash rules from both configs
  # are combined, rather than the override replacing the entire subtree.
  deepMerge =
    lhs: rhs:
    lhs
    // builtins.mapAttrs (
      key: rhsVal:
      if builtins.hasAttr key lhs && builtins.isAttrs lhs.${key} && builtins.isAttrs rhsVal then
        deepMerge lhs.${key} rhsVal
      else
        rhsVal
    ) rhs;

  baseConfig = builtins.fromJSON (builtins.readFile ../../../configs/opencode/opencode.json);
  overrideConfigs = map (f: builtins.fromJSON (builtins.readFile f)) cfg.overrides;
  mergedConfig = foldl' deepMerge baseConfig overrideConfigs;
in
{
  options.myConfig.development.opencode = {
    enable = mkEnableOption "OpenCode AI assistant configuration";
    overrides = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "List of JSON files to deep-merge over the base OpenCode config (in order, last wins)";
    };
  };

  config = mkIf cfg.enable {
    xdg.configFile."opencode/opencode.json".text = builtins.toJSON mergedConfig;
  };
}
