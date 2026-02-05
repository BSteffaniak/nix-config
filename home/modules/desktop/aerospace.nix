{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.aerospace;
in
{
  options.myConfig.desktop.aerospace = {
    enable = mkEnableOption "AeroSpace tiling window manager for macOS";
  };

  config = mkIf cfg.enable {
    # Install AeroSpace via homebrew cask (managed by nix-darwin)
    # The package is installed via homebrew, we just manage the config here

    # Install choose for GUI fuzzy finding
    home.packages = [ pkgs.choose-gui ];

    # Symlink the AeroSpace configuration
    xdg.configFile."aerospace/aerospace.toml".source = ../../../configs/aerospace/aerospace.toml;

    # Symlink fuzzy finder scripts
    xdg.configFile."aerospace/winfzf.sh" = {
      source = ../../../configs/aerospace/winfzf.sh;
      executable = true;
    };
    xdg.configFile."aerospace/workspacefzf.sh" = {
      source = ../../../configs/aerospace/workspacefzf.sh;
      executable = true;
    };

    # Fish shell completions for aerospace CLI
    programs.fish.interactiveShellInit = mkIf config.programs.fish.enable ''
      # AeroSpace shell completions
      if command -q aerospace
        aerospace completion fish | source
      end
    '';
  };
}
