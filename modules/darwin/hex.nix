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
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "kitlangton-hex"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
