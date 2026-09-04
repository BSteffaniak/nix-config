{
  config,
  lib,
  pkgs,
  ...
}:

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
    enable = lib.mkEnableOption "Desktop utilities configuration";

    fuzzel = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Fuzzel application launcher configuration";
    };

    waypaper = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Waypaper wallpaper manager configuration";
    };

    wallpaperFolder = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/Pictures/wallpapers";
      description = "Path to wallpapers folder (set per-host for hardware-specific paths)";
    };

    defaultWallpaper = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Default wallpaper filename (relative to wallpaperFolder)";
    };

    screenshot.enable = lib.mkEnableOption "screenshot tools (hyprshot, Linux only)";
    brightness.enable = lib.mkEnableOption "brightness controls (brightnessctl, Linux only)";
    inputDiagnostics.enable = lib.mkEnableOption "input diagnostic tools (libinput, evtest, Linux only)";
    calculator.enable = lib.mkEnableOption "calculator app (Qalculate, Linux only)";
    music.enable = lib.mkEnableOption "music player app (Elisa, Linux only)";
  };

  config = lib.mkMerge [
    {
      home.packages =
        with pkgs;
        lib.optionals pkgs.stdenv.isLinux (
          (lib.optional cfg.screenshot.enable hyprshot)
          ++ (lib.optional cfg.brightness.enable brightnessctl)
          ++ (lib.optionals cfg.inputDiagnostics.enable [
            libinput
            evtest
          ])
          ++ (lib.optional cfg.calculator.enable qalculate-gtk)
          ++ (lib.optional cfg.music.enable kdePackages.elisa)
        );
    }

    (lib.mkIf cfg.enable {
      # Fuzzel application launcher and Waypaper wallpaper manager
      xdg.configFile = {
        "fuzzel/fuzzel.ini" = lib.mkIf cfg.fuzzel {
          source = ../../../configs/fuzzel/fuzzel.ini;
        };

        "waypaper/config.ini" = lib.mkIf cfg.waypaper {
          text = lib.generators.toINI { } waypaperConfig;
        };

        "waypaper/random-wallpaper.sh" = lib.mkIf cfg.waypaper {
          source = ../../../configs/waypaper/random-wallpaper.sh;
          executable = true;
        };
      };
    })
  ];
}
