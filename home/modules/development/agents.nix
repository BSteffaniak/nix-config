{ lib, ... }:

{
  options.myConfig.development.agents = {
    permissions = {
      autoDiscover = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Auto-discover and merge all shared agent permission files from configs/agents/permissions/";
      };

      include = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "When autoDiscover is false, explicitly list which shared permission files to include (without .json)";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Shared permission files to exclude from auto-discovery (without .json)";
      };

      restricted = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Use <name>-restricted.json instead of <name>.json for these shared agent permissions";
      };

      yolo = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Use <name>-yolo.json instead of <name>.json for these shared agent permissions";
      };

      overrides = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        description = "Shared agent permission JSON files merged after discovered permissions";
      };
    };
  };
}
