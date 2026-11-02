{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.desktop.sketchybar;
in
{
  options.myConfig.desktop.sketchybar = {
    enable = lib.mkEnableOption "SketchyBar status bar for macOS";
  };

  config = lib.mkIf cfg.enable {
    # Bundle cleanup resets trust to the Brewfile declarations. Keep item-specific
    # trust here rather than granting it in a pre-activation command.
    # The pinned nix-darwin brew options do not yet expose `trusted`.
    homebrew.extraConfig = ''
      brew "felixkratz/formulae/sketchybar", trusted: true
    '';

    # Ensure homebrew is enabled when sketchybar is enabled
    myConfig.darwin.homebrew.enable = true;

    # Start SketchyBar as a service
    # Note: SketchyBar is typically started via brew services
    # Users should run: brew services start sketchybar
  };
}
