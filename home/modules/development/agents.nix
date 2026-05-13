{ lib, ... }:

with lib;

{
  options.myConfig.development.agents = {
    permissions = {
      autoDiscover = mkOption {
        type = types.bool;
        default = true;
        description = "Auto-discover and merge all shared agent permission files from configs/agents/permissions/";
      };

      include = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "When autoDiscover is false, explicitly list which shared permission files to include (without .json)";
      };

      exclude = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Shared permission files to exclude from auto-discovery (without .json)";
      };

      restricted = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Use <name>-restricted.json instead of <name>.json for these shared agent permissions";
      };

      yolo = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Use <name>-yolo.json instead of <name>.json for these shared agent permissions";
      };

      overrides = mkOption {
        type = types.listOf types.path;
        default = [ ];
        description = "Shared agent permission JSON files merged after discovered permissions";
      };
    };
  };
}
