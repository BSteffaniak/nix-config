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

  baseConfig = builtins.fromJSON (builtins.readFile ../../../configs/opencode/opencode.json);
  overrideConfigs = map (f: builtins.fromJSON (builtins.readFile f)) cfg.overrides;
  mergedConfig = foldl' myLib.deepMerge baseConfig overrideConfigs;
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
