{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.ghostty;
in
{
  options.myConfig.darwin.ghostty = {
    enable = mkEnableOption "Ghostty terminal emulator via Homebrew";
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "ghostty"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
