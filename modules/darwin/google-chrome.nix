{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.googleChrome;
in
{
  options.myConfig.darwin.googleChrome = {
    enable = mkEnableOption "Google Chrome browser via Homebrew";
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "google-chrome"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
