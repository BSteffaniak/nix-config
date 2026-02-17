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

    fastKeyRepeat = mkOption {
      type = types.bool;
      default = true;
      description = "Enable faster key repeat rate and shorter initial delay";
    };

    mouseSpeed = mkOption {
      type = types.nullOr types.float;
      default = 3.0;
      description = "Mouse tracking speed (0.0 to 3.0, or -1 to disable acceleration). Set to null to leave unmanaged.";
    };
  };

  config = mkIf config.myConfig.darwin.systemDefaults.enable {
    system.defaults = {
      dock.autohide = true;

      finder.CreateDesktop = !config.myConfig.darwin.systemDefaults.hideDesktopIcons;

      NSGlobalDomain.AppleInterfaceStyle = mkIf config.myConfig.darwin.systemDefaults.darkMode "Dark";
      NSGlobalDomain.KeyRepeat = mkIf config.myConfig.darwin.systemDefaults.fastKeyRepeat 1;
      NSGlobalDomain.InitialKeyRepeat = mkIf config.myConfig.darwin.systemDefaults.fastKeyRepeat 30;

      CustomUserPreferences.".GlobalPreferences"."com.apple.mouse.scaling" = mkIf (
        config.myConfig.darwin.systemDefaults.mouseSpeed != null
      ) config.myConfig.darwin.systemDefaults.mouseSpeed;
    };

    power.sleep.display = mkIf config.myConfig.darwin.systemDefaults.preventSleep "never";
  };
}
