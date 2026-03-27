{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.development.lspmux;
in
{
  options.myConfig.development.lspmux = {
    enable = mkEnableOption "LSP multiplexer configuration";
  };

  config = mkIf cfg.enable {
    xdg.configFile."lspmux/config.toml".source = ../../../configs/lspmux/config.toml;
  };
}
