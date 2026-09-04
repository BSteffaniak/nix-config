{ lib, ... }:

let
  mkCaskModule = import ../../lib/mk-cask-module.nix { inherit lib; };
in
{
  imports = [
    (mkCaskModule {
      name = "scrollReverser";
      cask = "scroll-reverser";
      description = "Scroll Reverser";

      extraOptions = {
        reverseMouse = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Reverse mouse scroll direction";
        };

        reverseVertical = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Reverse vertical scroll direction";
        };

        startAtLogin = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Start Scroll Reverser at login";
        };
      };

      # Set preferences and launch the app in a single agent to ensure
      # defaults are written before the app reads them
      extraConfig = cfg: {
        launchd.user.agents.scroll-reverser = lib.mkIf cfg.startAtLogin {
          serviceConfig = {
            Label = "com.pilotmoon.scroll-reverser.launcher";
            RunAtLoad = true;
            ProgramArguments = [
              "/bin/sh"
              "-c"
              (lib.concatStringsSep " && " [
                "defaults write com.pilotmoon.scroll-reverser InvertScrollingOn -bool true"
                "defaults write com.pilotmoon.scroll-reverser ReverseY -bool ${lib.boolToString cfg.reverseVertical}"
                "defaults write com.pilotmoon.scroll-reverser ReverseX -bool false"
                "defaults write com.pilotmoon.scroll-reverser ReverseTrackpad -bool false"
                "defaults write com.pilotmoon.scroll-reverser ReverseMouse -bool ${lib.boolToString cfg.reverseMouse}"
                "defaults write com.pilotmoon.scroll-reverser HideIcon -bool true"
                "open -a 'Scroll Reverser'"
              ])
            ];
          };
        };
      };
    })
  ];
}
