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
    # Install SketchyBar via homebrew
    # Note: The tap (FelixKratz/formulae) is declared in flake.nix (nix-homebrew.taps)
    homebrew.brews = [
      "sketchybar"
    ];

    # Establish formula-only trust in the same user environment as brew bundle.
    system.activationScripts.homebrew.text = lib.mkBefore ''
      if [ -f "${config.homebrew.brewPrefix}/brew" ]; then
        sudo --user=${lib.escapeShellArg config.homebrew.user} --set-home \
          "${config.homebrew.brewPrefix}/brew" trust --formula felixkratz/formulae/sketchybar
      fi
    '';

    # Ensure homebrew is enabled when sketchybar is enabled
    myConfig.darwin.homebrew.enable = true;

    # Start SketchyBar as a service
    # Note: SketchyBar is typically started via brew services
    # Users should run: brew services start sketchybar
  };
}
