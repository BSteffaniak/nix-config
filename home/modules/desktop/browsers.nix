# Browser applications installed via home-manager
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.browsers;
in
{
  options.myConfig.desktop.browsers = {
    firefox = {
      enable = mkEnableOption "Firefox web browser";
    };
  };

  config = {
    home.packages = with pkgs; (optional cfg.firefox.enable firefox);
  };
}
