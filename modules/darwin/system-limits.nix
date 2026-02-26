{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.systemLimits;
in
{
  options.myConfig.darwin.systemLimits = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "macOS system resource limits (file descriptors)";
    };

    maxFiles = {
      soft = mkOption {
        type = types.int;
        default = 65536;
        description = "Soft limit for maximum open files per process";
      };

      hard = mkOption {
        type = types.int;
        default = 200000;
        description = "Hard limit for maximum open files per process";
      };
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons.limit-maxfiles = {
      serviceConfig = {
        Label = "limit.maxfiles";
        ProgramArguments = [
          "launchctl"
          "limit"
          "maxfiles"
          (toString cfg.maxFiles.soft)
          (toString cfg.maxFiles.hard)
        ];
        RunAtLoad = true;
      };
    };
  };
}
