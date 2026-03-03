{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.hex;
in
{
  options.myConfig.darwin.hex = {
    enable = mkEnableOption "Hex voice-to-text app via Homebrew";

    startAtLogin = mkOption {
      type = types.bool;
      default = true;
      description = "Start Hex automatically at user login";
    };
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "kitlangton-hex"
    ];

    myConfig.darwin.homebrew.enable = true;

    launchd.user.agents.hex = mkIf cfg.startAtLogin {
      serviceConfig = {
        Label = "com.kitlangton.hex.launcher";
        RunAtLoad = true;
        ProgramArguments = [
          "/Applications/Hex.app/Contents/MacOS/Hex"
        ];
      };
    };
  };
}
