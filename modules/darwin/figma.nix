{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.figma;
in
{
  options.myConfig.darwin.figma = {
    enable = mkEnableOption "Figma design tool via Homebrew";
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "figma"
    ];

    myConfig.darwin.homebrew.enable = true;

    # Disable Figma's built-in auto-updater; updates should be managed by Homebrew
    system.defaults.CustomUserPreferences."com.figma.Desktop" = {
      SUEnableAutomaticChecks = false;
      SUAutomaticallyUpdate = false;
    };
  };
}
