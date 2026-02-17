{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.microsoftEdge;
in
{
  options.myConfig.darwin.microsoftEdge = {
    enable = mkEnableOption "Microsoft Edge browser via Homebrew";
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "microsoft-edge"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
