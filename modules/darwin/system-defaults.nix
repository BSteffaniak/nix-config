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

    darkMode = mkOption {
      type = types.bool;
      default = false;
      description = "Set macOS appearance to dark mode";
    };

    hideDesktopIcons = mkOption {
      type = types.bool;
      default = true;
      description = "Hide all icons on the desktop (files remain in ~/Desktop but are not shown)";
    };

    preventSleep = mkOption {
      type = types.bool;
      default = true;
      description = "Prevent display from dimming/sleeping (even on battery)";
    };
  };

  config = mkIf config.myConfig.darwin.systemDefaults.enable {
    system.defaults = {
      dock.autohide = true;

      finder.CreateDesktop = !config.myConfig.darwin.systemDefaults.hideDesktopIcons;

      NSGlobalDomain.AppleInterfaceStyle = mkIf config.myConfig.darwin.systemDefaults.darkMode "Dark";
    };

    power.sleep.display = mkIf config.myConfig.darwin.systemDefaults.preventSleep "never";
  };
}
