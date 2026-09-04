# Homebrew casks exposed as `myConfig.darwin.<name>.enable` flags.
#
# Each entry installs one cask and turns on Homebrew. Casks that need extra
# configuration (launchd agents, defaults, certificates) still live in their
# own files but use the same helper.
{ lib, ... }:
let
  mkCaskModule = import ../../lib/mk-cask-module.nix { inherit lib; };

  simpleCasks = {
    ghostty = {
      cask = "ghostty";
      description = "Ghostty terminal emulator";
    };
    googleChrome = {
      cask = "google-chrome";
      description = "Google Chrome browser";
    };
    hex = {
      cask = "kitlangton-hex";
      description = "Hex voice-to-text app";
    };
    istatMenus = {
      cask = "istat-menus";
      description = "iStat Menus system monitor";
    };
    microsoftEdge = {
      cask = "microsoft-edge";
      description = "Microsoft Edge browser";
    };
    roon = {
      cask = "roon";
      description = "Roon music player";
    };
    signal = {
      cask = "signal";
      description = "Signal Desktop messenger";
    };
  };
in
{
  imports = lib.mapAttrsToList (name: spec: mkCaskModule (spec // { inherit name; })) simpleCasks ++ [
    (mkCaskModule {
      name = "figma";
      cask = "figma";
      description = "Figma design tool";
      # Disable Figma's built-in auto-updater; updates are managed by Homebrew.
      extraConfig = _: {
        system.defaults.CustomUserPreferences."com.figma.Desktop" = {
          SUEnableAutomaticChecks = false;
          SUAutomaticallyUpdate = false;
        };
      };
    })
  ];
}
