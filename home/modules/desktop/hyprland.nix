# User-level Hyprland configuration
# Note: The Hyprland compositor itself must be installed at system level
# This module only manages user configuration files
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.desktop.hyprland;
in
{
  options.myConfig.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager configuration";

    configText = lib.mkOption {
      type = lib.types.lines;
      internal = true;
      readOnly = true;
      description = "Shared Hyprland configuration consumed by system and standalone sessions.";
    };

    monitorsConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to host-specific monitors.conf (should be set per-host)";
    };

    workspacesConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to host-specific workspaces.conf (optional)";
    };
  };

  config = lib.mkIf cfg.enable {
    myConfig.desktop.hyprland.configText =
      builtins.readFile ../../../configs/hyprland/hyprland.conf
      +
        lib.optionalString
          (
            pkgs.stdenv.hostPlatform.system == "x86_64-linux"
            && config.myConfig.desktop.hex.enable
            && config.myConfig.desktop.hex.openOnLogin
          )
          ''

            # Direct Hyprland sessions do not necessarily start graphical-session.target.
            # Hex's client captures the current display environment for its user service.
            exec-once = ${lib.getExe config.programs.hex.package} start
            exec-shutdown = ${lib.getExe config.programs.hex.package} stop
          '';

    wayland.windowManager.hyprland.extraConfig = lib.mkIf config.wayland.windowManager.hyprland.enable cfg.configText;

    # Share the same configuration with Home Manager-managed compositors.
    xdg.configFile = {
      # Shared config and scripts
      "hypr/hyprland.conf".text = lib.mkIf (!config.wayland.windowManager.hyprland.enable) cfg.configText;
      "hypr/display_off.sh" = {
        source = ../../../configs/hyprland/display_off.sh;
        executable = true;
      };
      "hypr/winfzf.sh" = {
        source = ../../../configs/hyprland/winfzf.sh;
        executable = true;
      };

      # Host-specific configs (only if provided)
      "hypr/monitors.conf" = lib.mkIf (cfg.monitorsConfig != null) {
        source = cfg.monitorsConfig;
      };
      "hypr/workspaces.conf" = lib.mkIf (cfg.workspacesConfig != null) {
        source = cfg.workspacesConfig;
      };
    };
  };
}
