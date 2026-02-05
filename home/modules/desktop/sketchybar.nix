{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.sketchybar;
in
{
  options.myConfig.desktop.sketchybar = {
    enable = mkEnableOption "SketchyBar status bar for macOS";
  };

  config = mkIf cfg.enable {
    # SketchyBar is installed via homebrew cask (managed by nix-darwin)
    # We just manage the configuration here

    # Symlink the SketchyBar configuration
    xdg.configFile = {
      "sketchybar/sketchybarrc".source = ../../../configs/sketchybar/sketchybarrc;
      "sketchybar/plugins/aerospace.sh".source = ../../../configs/sketchybar/plugins/aerospace.sh;
      "sketchybar/plugins/battery.sh".source = ../../../configs/sketchybar/plugins/battery.sh;
      "sketchybar/plugins/clock.sh".source = ../../../configs/sketchybar/plugins/clock.sh;
    };
  };
}
