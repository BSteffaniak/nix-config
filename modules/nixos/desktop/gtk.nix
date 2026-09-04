{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myConfig.desktop.gtk = {
    enable = lib.mkEnableOption "GTK and desktop integration";
  };

  config = lib.mkIf config.myConfig.desktop.gtk.enable {
    # XDG Portals
    xdg = {
      autostart.enable = true;
      portal = {
        enable = true;
        extraPortals = [
          pkgs.xdg-desktop-portal
          pkgs.xdg-desktop-portal-gtk
        ];
      };
    };

    environment.systemPackages = with pkgs; [
      polkit_gnome
      adwaita-icon-theme
      gnome-themes-extra
      gsettings-desktop-schemas
      xdg-utils
      xdg-desktop-portal
      xdg-desktop-portal-gtk
      qt5.qtwayland
      qt6.qmake
      qt6.qtwayland
      adwaita-qt
      adwaita-qt6
      nwg-displays
      nemo
      gnome-tweaks
    ];

    environment.sessionVariables = {
      POLKIT_AUTH_AGENT = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
      GTK_USE_PORTAL = "1";
      NIXOS_XDG_OPEN_USE_PORTAL = "1";
    };

    services.gnome = {
      sushi.enable = true;
      gnome-keyring.enable = true;
    };

    programs.thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
      ];
    };

    services.gvfs.enable = true;
    services.tumbler.enable = true;
  };
}
