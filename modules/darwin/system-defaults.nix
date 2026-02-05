{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options.myConfig.darwin.systemDefaults = {
    enable = mkEnableOption "macOS system defaults";

    hideDesktopIcons = mkOption {
      type = types.bool;
      default = true;
      description = "Hide all icons on the desktop (files remain in ~/Desktop but are not shown)";
    };
  };

  config = mkIf config.myConfig.darwin.systemDefaults.enable {
    system.defaults = {
      dock.autohide = true;

      finder.CreateDesktop = !config.myConfig.darwin.systemDefaults.hideDesktopIcons;
    };
  };
}
