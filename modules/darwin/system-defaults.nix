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

    use24HourClock = mkOption {
      type = types.bool;
      default = true;
      description = "Use 24-hour clock format in the menu bar";
    };
  };

  config = mkIf config.myConfig.darwin.systemDefaults.enable {
    system.defaults = {
      dock.autohide = true;

      finder.CreateDesktop = !config.myConfig.darwin.systemDefaults.hideDesktopIcons;

      NSGlobalDomain.AppleInterfaceStyle = mkIf config.myConfig.darwin.systemDefaults.darkMode "Dark";
      NSGlobalDomain.AppleICUForce24HourTime = config.myConfig.darwin.systemDefaults.use24HourClock;
      NSGlobalDomain.KeyRepeat = mkIf config.myConfig.darwin.systemDefaults.fastKeyRepeat 1;
      NSGlobalDomain.InitialKeyRepeat = mkIf config.myConfig.darwin.systemDefaults.fastKeyRepeat 50;

      CustomUserPreferences.".GlobalPreferences"."com.apple.mouse.scaling" = mkIf (
        config.myConfig.darwin.systemDefaults.mouseSpeed != null
      ) config.myConfig.darwin.systemDefaults.mouseSpeed;

      # Disable screensaver and screen lock when preventSleep is enabled
      screensaver.askForPassword = mkIf config.myConfig.darwin.systemDefaults.preventSleep false;
      screensaver.askForPasswordDelay = mkIf config.myConfig.darwin.systemDefaults.preventSleep 0;

      CustomUserPreferences."com.apple.screensaver".idleTime =
        mkIf config.myConfig.darwin.systemDefaults.preventSleep 0;
    };

    power.sleep.display = mkIf config.myConfig.darwin.systemDefaults.preventSleep "never";

    # Use pmset directly to prevent display sleep on all power sources (AC, battery, UPS)
    # systemsetup -setDisplaySleep is unreliable on newer macOS versions
    system.activationScripts.postActivation.text = mkIf config.myConfig.darwin.systemDefaults.preventSleep ''
      echo "configuring display sleep prevention (all power sources)..." >&2
      pmset -a displaysleep 0
    '';
  };
}
