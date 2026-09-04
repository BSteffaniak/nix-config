# GTK theming for Linux desktops.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.desktop.gtk;
in
{
  options.myConfig.desktop.gtk = {
    enable = lib.mkEnableOption "GTK theming configuration";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "Adwaita-dark";
      description = "GTK theme name";
    };

    themePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gnome-themes-extra;
      description = "GTK theme package";
    };

    iconTheme = lib.mkOption {
      type = lib.types.str;
      default = "Adwaita";
      description = "Icon theme name";
    };

    iconThemePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.adwaita-icon-theme;
      description = "Icon theme package";
    };

    cursorTheme = lib.mkOption {
      type = lib.types.str;
      default = "Adwaita";
      description = "Cursor theme name";
    };

    cursorThemePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.adwaita-icon-theme;
      description = "Cursor theme package";
    };

    font = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Sans";
        description = "GTK font name";
      };

      size = lib.mkOption {
        type = lib.types.int;
        default = 11;
        description = "GTK font size";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    gtk = {
      enable = true;

      font = {
        inherit (cfg.font) name size;
      };

      theme = {
        name = cfg.theme;
        package = cfg.themePackage;
      };

      iconTheme = {
        name = cfg.iconTheme;
        package = cfg.iconThemePackage;
      };

      cursorTheme = {
        name = cfg.cursorTheme;
        package = cfg.cursorThemePackage;
      };

      gtk3.extraConfig = {
        "gtk-application-prefer-dark-theme" = 1;
        "gtk-cursor-theme-name" = cfg.cursorTheme;
      };

      gtk4.extraConfig = {
        "gtk-application-prefer-dark-theme" = 1;
        "gtk-cursor-theme-name" = cfg.cursorTheme;
      };
    };
  };
}
