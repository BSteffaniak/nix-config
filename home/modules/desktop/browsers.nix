# Browser applications installed via home-manager
#
# Firefox on darwin requires the nixpkgs-firefox-darwin overlay
# (registered in overlays/firefox-darwin.nix) since the nixpkgs
# firefox package is broken on macOS.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.desktop.browsers;
in
{
  options.myConfig.desktop.browsers = {
    firefox = {
      enable = lib.mkEnableOption "Firefox web browser";
    };
  };

  config = lib.mkIf cfg.firefox.enable {
    programs.firefox.enable = true;
  };
}
