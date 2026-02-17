{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.signal;
in
{
  options.myConfig.darwin.signal = {
    enable = mkEnableOption "Signal Desktop messenger via Homebrew";
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "signal"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
