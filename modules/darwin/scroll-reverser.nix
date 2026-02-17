{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.scrollReverser;
in
{
  options.myConfig.darwin.scrollReverser = {
    enable = mkEnableOption "Scroll Reverser via Homebrew";

    reverseMouse = mkOption {
      type = types.bool;
      default = true;
      description = "Reverse mouse scroll direction";
    };

    startAtLogin = mkOption {
      type = types.bool;
      default = true;
      description = "Start Scroll Reverser at login";
    };
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "scroll-reverser"
    ];

    myConfig.darwin.homebrew.enable = true;

    # Set preferences and launch the app in a single agent to ensure
    # defaults are written before the app reads them
    launchd.user.agents.scroll-reverser = mkIf cfg.startAtLogin {
      serviceConfig = {
        Label = "com.pilotmoon.scroll-reverser.launcher";
        RunAtLoad = true;
        ProgramArguments = [
          "/bin/sh"
          "-c"
          (concatStringsSep " && " [
            "defaults write com.pilotmoon.scroll-reverser InvertScrollingOn -bool true"
            "defaults write com.pilotmoon.scroll-reverser ReverseY -bool true"
            "defaults write com.pilotmoon.scroll-reverser ReverseX -bool false"
            "defaults write com.pilotmoon.scroll-reverser ReverseTrackpad -bool false"
            "defaults write com.pilotmoon.scroll-reverser ReverseMouse -bool ${boolToString cfg.reverseMouse}"
            "open -a 'Scroll Reverser'"
          ])
        ];
      };
    };
  };
}
