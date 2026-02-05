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

    # Symlink workspace-monitor persistence scripts
    xdg.configFile."aerospace/on-workspace-change.sh" = {
      source = ../../../configs/aerospace/on-workspace-change.sh;
      executable = true;
    };
    xdg.configFile."aerospace/detect-monitor-change.sh" = {
      source = ../../../configs/aerospace/detect-monitor-change.sh;
      executable = true;
    };
    xdg.configFile."aerospace/restore-workspace-monitors.sh" = {
      source = ../../../configs/aerospace/restore-workspace-monitors.sh;
      executable = true;
    };

    # NOTE: AeroSpace CLI does not currently support shell completions
    # (no `aerospace completion` subcommand exists)
  };
}
