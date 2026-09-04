{ lib, ... }:

let
  mkCaskModule = import ../../lib/mk-cask-module.nix { inherit lib; };
in
{
  imports = [
    (mkCaskModule {
      name = "keepingYouAwake";
      cask = "keepingyouawake";
      description = "KeepingYouAwake caffeine app";

      extraOptions = {
        startAtLogin = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Start KeepingYouAwake at login";
        };

        activateOnLaunch = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Activate sleep prevention immediately when KeepingYouAwake starts";
        };
      };

      extraConfig = cfg: {
        launchd.user.agents.keepingyouawake = lib.mkIf cfg.startAtLogin {
          serviceConfig = {
            Label = "info.marcel-dierkes.KeepingYouAwake.launcher";
            RunAtLoad = true;
            ProgramArguments = [
              "/bin/sh"
              "-c"
              (lib.concatStringsSep " && " (
                lib.optional cfg.activateOnLaunch "defaults write info.marcel-dierkes.KeepingYouAwake 'info.marcel-dierkes.KeepingYouAwake.ActivateOnLaunch' -bool true"
                ++ [ "open -a 'KeepingYouAwake'" ]
              ))
            ];
          };
        };
      };
    })
  ];
}
