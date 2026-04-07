{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.keepingYouAwake;
in
{
  options.myConfig.darwin.keepingYouAwake = {
    enable = mkEnableOption "KeepingYouAwake caffeine app via Homebrew";

    startAtLogin = mkOption {
      type = types.bool;
      default = true;
      description = "Start KeepingYouAwake at login";
    };

    activateOnLaunch = mkOption {
      type = types.bool;
      default = true;
      description = "Activate sleep prevention immediately when KeepingYouAwake starts";
    };
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "keepingyouawake"
    ];

    myConfig.darwin.homebrew.enable = true;

    launchd.user.agents.keepingyouawake = mkIf cfg.startAtLogin {
      serviceConfig = {
        Label = "info.marcel-dierkes.KeepingYouAwake.launcher";
        RunAtLoad = true;
        ProgramArguments = [
          "/bin/sh"
          "-c"
          (concatStringsSep " && " (
            optional cfg.activateOnLaunch "defaults write info.marcel-dierkes.KeepingYouAwake 'info.marcel-dierkes.KeepingYouAwake.ActivateOnLaunch' -bool true"
            ++ [
              "open -a 'KeepingYouAwake'"
            ]
          ))
        ];
      };
    };
  };
}
