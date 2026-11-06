{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.devops.datadog.enable = lib.mkEnableOption "Datadog CLI (pup)";

  config = lib.mkIf config.myConfig.devops.datadog.enable {
    home.packages = [ pkgs.datadog-pup ];
  };
}
