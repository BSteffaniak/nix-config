{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.roon;
in
{
  options.myConfig.darwin.roon = {
    enable = mkEnableOption "Roon music player via Homebrew";
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "roon"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
