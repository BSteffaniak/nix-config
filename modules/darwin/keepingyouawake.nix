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
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "keepingyouawake"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
