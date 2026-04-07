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
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "keepingyouawake"
    ];

    myConfig.darwin.homebrew.enable = true;

    launchd.user.agents.keepingyouawake = mkIf cfg.startAtLogin {
      serviceConfig = {
        Label = "info.marcel-dez.KeepingYouAwake.launcher";
        RunAtLoad = true;
        ProgramArguments = [
          "/usr/bin/open"
          "-a"
          "KeepingYouAwake"
        ];
      };
    };
  };
}
