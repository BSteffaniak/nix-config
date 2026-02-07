# Browser applications installed via home-manager
#
# Firefox on darwin requires the nixpkgs-firefox-darwin overlay
# (registered in lib/overlays/firefox-darwin.nix) since the nixpkgs
# firefox package is broken on macOS.
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

  config = mkIf cfg.firefox.enable {
    programs.firefox.enable = true;
  };
}
