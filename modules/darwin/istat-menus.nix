{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.istatMenus;
in
{
  options.myConfig.darwin.istatMenus = {
    enable = mkEnableOption "iStat Menus system monitor via Homebrew";
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "istat-menus"
    ];

    myConfig.darwin.homebrew.enable = true;
  };
}
