{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.act;
in
{
  options.myConfig.development.act = {
    enable = lib.mkEnableOption "Act (GitHub Actions locally) configuration";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."act/actrc".source = ../../../configs/act/actrc;
  };
}
