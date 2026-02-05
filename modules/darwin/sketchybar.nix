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
    # Install SketchyBar via homebrew
    # Note: The tap (FelixKratz/formulae) is declared in flake.nix (nix-homebrew.taps)
    homebrew.brews = [
      "sketchybar"
    ];

    # Ensure homebrew is enabled when sketchybar is enabled
    myConfig.darwin.homebrew.enable = true;

    # Start SketchyBar as a service
    # Note: SketchyBar is typically started via brew services
    # Users should run: brew services start sketchybar
  };
}
