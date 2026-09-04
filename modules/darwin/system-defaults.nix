{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.darwin.systemDefaults;
  display-ctl-src = ../../pkgs/display-ctl/main.m;

  # Lazy-build script: compiles display-ctl at activation time using the
  # system's clang/Objective-C toolchain, caching the binary so it only
  # recompiles when the source changes. Uses Objective-C instead of Swift
  # to avoid Swift compiler/SDK .swiftinterface version mismatches.
  display-ctl-compile = ''
    DISPLAY_CTL_DIR="/var/cache/display-ctl"
    DISPLAY_CTL_SRC="${display-ctl-src}"
    DISPLAY_CTL_BIN="$DISPLAY_CTL_DIR/display-ctl"
    DISPLAY_CTL_HASH="$DISPLAY_CTL_DIR/.source-hash"

    CURRENT_HASH=$(/usr/bin/shasum -a 256 "$DISPLAY_CTL_SRC" | /usr/bin/cut -d' ' -f1)

    /bin/mkdir -p "$DISPLAY_CTL_DIR"

    if [ ! -x "$DISPLAY_CTL_BIN" ] || [ ! -f "$DISPLAY_CTL_HASH" ] || [ "$(/bin/cat "$DISPLAY_CTL_HASH")" != "$CURRENT_HASH" ]; then
      echo "compiling display-ctl..." >&2
      SDK_PATH=$(/usr/bin/xcrun --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")
      if /Library/Developer/CommandLineTools/usr/bin/clang \
        -isysroot "$SDK_PATH" \
        -O2 \
        -fobjc-arc \
        -o "$DISPLAY_CTL_BIN" \
        -F /System/Library/PrivateFrameworks \
        -framework CoreBrightness \
        -framework DisplayServices \
        -framework ApplicationServices \
        -framework Foundation \
        "$DISPLAY_CTL_SRC" 2>&1; then
        echo "$CURRENT_HASH" > "$DISPLAY_CTL_HASH"
      else
        echo "warning: display-ctl compilation failed, skipping display settings" >&2
        /bin/rm -f "$DISPLAY_CTL_BIN" "$DISPLAY_CTL_HASH"
        DISPLAY_CTL_BIN=""
      fi
    fi
  '';

  needsDisplayCtl = cfg.disableAutoBrightness || cfg.disableTrueTone;

  keyboardRepeatScript = pkgs.writeShellScript "apply-keyboard-repeat" ''
    /usr/bin/hidutil property --set '{"HIDInitialKeyRepeat":166666667,"HIDKeyRepeat":8333333}' >/dev/null
  '';
in
{
  options.myConfig.darwin.systemDefaults = {
    enable = lib.mkEnableOption "macOS system defaults";

    darkMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Set macOS appearance to dark mode";
    };

    hideDesktopIcons = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Hide all icons on the desktop (files remain in ~/Desktop but are not shown)";
    };

    preventSleep = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prevent display from dimming/sleeping (even on battery)";
    };

    fastKeyRepeat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable faster key repeat rate and shorter initial delay";
    };

    mouseSpeed = lib.mkOption {
      type = lib.types.nullOr lib.types.float;
      default = 3.0;
      description = "Mouse tracking speed (0.0 to 3.0, or -1 to disable acceleration). Set to null to leave unmanaged.";
    };

    use24HourClock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use 24-hour clock format in the menu bar";
    };

    showClockSeconds = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show seconds in the menu bar clock";
    };

    disableAutoBrightness = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable automatic display brightness adjustment based on ambient light";
    };

    disableTrueTone = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable True Tone (automatic color temperature adjustment based on ambient light)";
    };
  };

  config = lib.mkIf cfg.enable {
    system.defaults = {
      dock.autohide = true;

      finder.CreateDesktop = !cfg.hideDesktopIcons;

      NSGlobalDomain.AppleInterfaceStyle = lib.mkIf cfg.darkMode "Dark";
      NSGlobalDomain.AppleICUForce24HourTime = cfg.use24HourClock;

      menuExtraClock.ShowSeconds = cfg.showClockSeconds;
      NSGlobalDomain.KeyRepeat = lib.mkIf cfg.fastKeyRepeat 1;
      NSGlobalDomain.InitialKeyRepeat = lib.mkIf cfg.fastKeyRepeat 2;
      NSGlobalDomain.ApplePressAndHoldEnabled = lib.mkIf cfg.fastKeyRepeat false;

      CustomUserPreferences.".GlobalPreferences"."com.apple.mouse.scaling" = lib.mkIf (
        cfg.mouseSpeed != null
      ) cfg.mouseSpeed;

      # Disable screensaver and screen lock when preventSleep is enabled
      screensaver.askForPassword = lib.mkIf cfg.preventSleep false;
      screensaver.askForPasswordDelay = lib.mkIf cfg.preventSleep 0;

      CustomUserPreferences."com.apple.screensaver".idleTime = lib.mkIf cfg.preventSleep 0;

    };

    power.sleep.display = lib.mkIf cfg.preventSleep "never";

    launchd.user.agents.keyboard-repeat = lib.mkIf cfg.fastKeyRepeat {
      serviceConfig = {
        Label = "com.braden.keyboard-repeat";
        ProgramArguments = [ "${keyboardRepeatScript}" ];
        RunAtLoad = true;
        StandardOutPath = "/Users/${config.myConfig.username}/Library/Logs/keyboard-repeat.log";
        StandardErrorPath = "/Users/${config.myConfig.username}/Library/Logs/keyboard-repeat.err.log";
      };
    };

    # Use pmset directly to prevent display sleep on all power sources (AC, battery, UPS)
    # systemsetup -setDisplaySleep is unreliable on newer macOS versions
    system.activationScripts.postActivation.text = lib.concatStrings [
      (lib.optionalString cfg.preventSleep ''
        echo "configuring display sleep prevention (all power sources)..." >&2
        pmset -a displaysleep 0
      '')
      (lib.optionalString cfg.fastKeyRepeat ''
        echo "configuring live keyboard repeat rate..." >&2
        ${keyboardRepeatScript} || true
      '')
      # Use display-ctl (Objective-C CLI) to toggle auto-brightness and True Tone
      # via Apple's private CoreBrightness/DisplayServices framework APIs.
      # defaults write does NOT work for these settings on modern macOS.
      # The binary is compiled lazily at activation time using clang to avoid
      # Swift compiler/SDK version mismatches.
      (lib.optionalString needsDisplayCtl display-ctl-compile)
      (lib.optionalString cfg.disableAutoBrightness ''
        if [ -x "$DISPLAY_CTL_BIN" ]; then
          echo "disabling automatic display brightness..." >&2
          "$DISPLAY_CTL_BIN" --auto-brightness off || true
        fi
      '')
      (lib.optionalString cfg.disableTrueTone ''
        if [ -x "$DISPLAY_CTL_BIN" ]; then
          echo "disabling True Tone..." >&2
          "$DISPLAY_CTL_BIN" --true-tone off || true
        fi
      '')
    ];
  };
}
