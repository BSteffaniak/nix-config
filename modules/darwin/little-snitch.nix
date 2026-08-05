{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.littleSnitch;
in
{
  options.myConfig.darwin.littleSnitch = {
    enable = mkEnableOption "Little Snitch host-based application firewall via Homebrew";
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "little-snitch"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
