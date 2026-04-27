{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.utilities;

  # Generate waypaper config.ini with configurable wallpaper folder
  waypaperConfig = {
    Settings = {
      language = "en";
      folder = cfg.wallpaperFolder;
      backend = "swww";
      monitors = "All";
      fill = "fill";
      sort = "name";
      color = "#ffffff";
      subfolders = false;
      number_of_columns = 3;
      post_command = "";
      show_hidden = false;
      show_gifs_only = false;
      swww_transition_type = "simple";
      swww_transition_step = 90;
      swww_transition_angle = 0;
      swww_transition_duration = 2;
      swww_transition_fps = 60;
      use_xdg_state = false;
      wallpaper = "${cfg.wallpaperFolder}/${cfg.defaultWallpaper}";
      show_path_in_tooltip = true;
      all_subfolders = false;
      mpvpaper_sound = false;
      mpvpaper_options = "";
    };
  };
in
{
  options.myConfig.desktop.utilities = {
    enable = mkEnableOption "Desktop utilities configuration";

    fuzzel = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Fuzzel application launcher configuration";
    };

    waypaper = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Waypaper wallpaper manager configuration";
    };

    wallpaperFolder = mkOption {
      type = types.str;
      default = "$HOME/Pictures/wallpapers";
      description = "Path to wallpapers folder (set per-host for hardware-specific paths)";
    };

    defaultWallpaper = mkOption {
      type = types.str;
      default = "";
      description = "Default wallpaper filename (relative to wallpaperFolder)";
    };

    bitwarden.enable = mkEnableOption "Bitwarden desktop app";
    screenshot.enable = mkEnableOption "screenshot tools (hyprshot, Linux only)";
    brightness.enable = mkEnableOption "brightness controls (brightnessctl, Linux only)";
    inputDiagnostics.enable = mkEnableOption "input diagnostic tools (libinput, evtest, Linux only)";
    calculator.enable = mkEnableOption "calculator app (Qalculate, Linux only)";
    music.enable = mkEnableOption "music player app (Elisa, Linux only)";
  };

  config = mkMerge [
    {
      home.packages =
        with pkgs;
        (optional cfg.bitwarden.enable bitwarden-desktop)
        ++ optionals pkgs.stdenv.isLinux (
          (optional cfg.screenshot.enable hyprshot)
          ++ (optional cfg.brightness.enable brightnessctl)
          ++ (optionals cfg.inputDiagnostics.enable [
            libinput
            evtest
          ])
          ++ (optional cfg.calculator.enable qalculate-gtk)
          ++ (optional cfg.music.enable kdePackages.elisa)
        );
    }

    (mkIf cfg.enable {
      # Fuzzel application launcher and Waypaper wallpaper manager
      xdg.configFile = {
        "fuzzel/fuzzel.ini" = mkIf cfg.fuzzel {
          source = ../../../configs/fuzzel/fuzzel.ini;
        };

        "waypaper/config.ini" = mkIf cfg.waypaper {
          text = lib.generators.toINI { } waypaperConfig;
        };

        "waypaper/random-wallpaper.sh" = mkIf cfg.waypaper {
          source = ../../../configs/waypaper/random-wallpaper.sh;
          executable = true;
        };
      };
    })
  ];
}
