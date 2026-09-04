{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  options.myConfig.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager";

    monitorsConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to host-specific monitors.conf";
    };

    workspacesConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to host-specific workspaces.conf";
    };
  };

  config = lib.mkIf config.myConfig.desktop.hyprland.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.systemPackages = with pkgs; [
      hyprland-protocols
      hyprpicker
      hyprpaper
      swayidle
      swaylock
      xdg-desktop-portal-hyprland
      waypaper
      fuzzel
      wofi
      grim
      wlr-randr
      ydotool
      wl-clipboard
      swaynotificationcenter
      inputs.swww.packages."${pkgs.stdenv.hostPlatform.system}".default
    ];

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      CLUTTER_BACKEND = "wayland";
      WLR_RENDERER = "vulkan";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      GBM_BACKEND = "nvidia-drm";
    };
  };
}
