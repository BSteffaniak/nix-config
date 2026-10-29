# Optional Nix-built Hyprland session for standalone Linux Home Manager.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig.desktop.hyprland.standalone;
  lockCommand = lib.escapeShellArgs ([ cfg.lockerExecutable ] ++ cfg.lockerArguments);
  hyprland = config.wayland.windowManager.hyprland.finalPackage;
  session = pkgs.writeShellApplication {
    name = "start-hyprland";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if [[ ! -d /run/opengl-driver/lib/dri ]]; then
        echo "Nix GPU drivers are not configured. Run setup-hyprland first." >&2
        exit 1
      fi
      # GDM does not necessarily load Home Manager's session environment.
      if [[ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]]; then
        # Home Manager's POSIX environment script expects unset variables to
        # expand to empty strings; writeShellApplication enables nounset.
        set +u
        # shellcheck source=/dev/null
        source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
        set -u
      fi
      export PATH="$HOME/.nix-profile/bin:$PATH"
      export XDG_DATA_DIRS="$HOME/.nix-profile/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
      export XDG_CURRENT_DESKTOP=Hyprland
      export XDG_SESSION_DESKTOP=Hyprland
      export XDG_SESSION_TYPE=wayland
      # Do not force Wayland or Intel graphics variables into the GNOME session.
      export NIXOS_OZONE_WL=1
      export MOZ_ENABLE_WAYLAND=1
      trap 'systemctl --user stop hyprland-session.target' EXIT
      ${hyprland}/bin/Hyprland
    '';
  };
  setup = pkgs.writeShellApplication {
    name = "setup-hyprland";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [[ "$EUID" -eq 0 ]]; then
        echo "Run as your normal user; this command requests sudo only for system setup." >&2
        exit 1
      fi
      if [[ ! -d /run/systemd/system ]]; then
        echo "This setup requires a host booted with systemd." >&2
        exit 1
      fi
      if ! command -v sudo >/dev/null; then
        echo "Install sudo and ensure your account can use it for system setup." >&2
        exit 1
      fi
      if [[ ! -x ${lib.escapeShellArg cfg.lockerExecutable} ]]; then
        echo "Install a system-integrated screen locker and set myConfig.desktop.hyprland.standalone.lockerExecutable to its absolute path." >&2
        exit 1
      fi
      if [[ ! -d /usr/share/wayland-sessions ]]; then
        echo "Install a display manager supporting /usr/share/wayland-sessions first." >&2
        exit 1
      fi
      if [[ ! -x "$HOME/.nix-profile/bin/start-hyprland" ]]; then
        echo "Activate the Home Manager configuration before running setup-hyprland." >&2
        exit 1
      fi
      sudo ${lib.getExe config.targets.genericLinux.gpu.setupPackage}
      desktop=$(mktemp)
      trap 'rm -f "$desktop"' EXIT
      # GDM checks TryExec before authentication, when private profile paths
      # may be inaccessible. Exec is resolved after login as the session user.
      # Omit TryExec rather than exposing ~/.local/state to the greeter.
      cat > "$desktop" <<EOF
      [Desktop Entry]
      Name=Hyprland (Nix)
      Comment=Experimental Nix-managed Hyprland; existing desktop sessions remain available
      Exec=$HOME/.nix-profile/bin/start-hyprland
      Type=Application
      DesktopNames=Hyprland
      EOF
      sudo ${pkgs.coreutils}/bin/install -Dm644 "$desktop" /usr/share/wayland-sessions/hyprland-nix.desktop
      echo "Setup complete. Log out and select Hyprland (Nix) in the login screen's session menu."
      echo "Keep your existing desktop available as your fallback. No display manager restart is needed."
    '';
  };
in
{
  options.myConfig.desktop.hyprland.standalone = {
    enable = lib.mkEnableOption "experimental Nix-managed Hyprland session on systemd Linux (run setup-hyprland after activation)";
    lockerExecutable = lib.mkOption {
      type = lib.types.strMatching "/[^\n]+";
      default = "/usr/bin/swaylock";
      description = "Absolute path to a host-installed, PAM-integrated screen locker. Install and test it using your distribution's package manager.";
    };
    lockerArguments = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "-f"
        "-c"
        "202020"
      ];
      description = "Arguments for the screen locker; defaults are for swaylock.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux && !config.myConfig.desktop.hyprland.enable;
        message = "The standalone Hyprland session supplies its own laptop config; do not also enable the shared desktop Hyprland config.";
      }
    ];

    targets.genericLinux.enable = true;
    targets.genericLinux.gpu.enable = true;

    home.packages = [
      session
      setup
      pkgs.fuzzel
      pkgs.wl-clipboard
      pkgs.brightnessctl
      pkgs.pavucontrol
    ];

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = true;
      systemd.variables = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "HYPRLAND_INSTANCE_SIGNATURE"
        "XDG_CURRENT_DESKTOP"
        "XDG_SESSION_DESKTOP"
        "XDG_SESSION_TYPE"
        "XDG_DATA_DIRS"
        "PATH"
      ];
      settings = {
        "$mod" = "SUPER";
        monitor = ",preferred,auto,1";
        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          layout = "dwindle";
        };
        input = {
          kb_layout = "us";
          touchpad = {
            natural_scroll = true;
            tap-to-click = true;
          };
        };
        decoration.rounding = 8;
        exec-once = [ "${pkgs.ghostty}/bin/ghostty" ];
        bind = [
          "$mod, Q, exec, ${pkgs.ghostty}/bin/ghostty"
          "$mod, R, exec, ${pkgs.fuzzel}/bin/fuzzel"
          "$mod, C, killactive,"
          "$mod, V, togglefloating,"
          "$mod, F, fullscreen,"
          "$mod, L, exec, ${lockCommand}"
          "$mod SHIFT, E, exit,"
          "$mod, left, movefocus, l"
          "$mod, right, movefocus, r"
          "$mod, up, movefocus, u"
          "$mod, down, movefocus, d"
        ]
        ++ lib.concatMap (
          n:
          let
            w = toString n;
          in
          [
            "$mod, ${w}, workspace, ${w}"
            "$mod SHIFT, ${w}, movetoworkspace, ${w}"
          ]
        ) (lib.range 1 9);
        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];
        bindel = [
          ", XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ", XF86MonBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl set +5%"
          ", XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%-"
        ];
        bindl = [
          ", XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ];
      };
    };

    # The host's system portal service does not know Nix's portal search paths.
    # Prefer the matching Nix D-Bus-activated units, including GNOME's backend.
    # No WantedBy: activation must not start a Hyprland backend inside GNOME.
    xdg.configFile = builtins.listToAttrs (
      map
        (entry: {
          name = "systemd/user/${entry.name}.service";
          value.source = "${entry.package}/lib/systemd/user/${entry.name}.service";
        })
        [
          {
            name = "xdg-desktop-portal";
            package = pkgs.xdg-desktop-portal;
          }
          {
            name = "xdg-document-portal";
            package = pkgs.xdg-desktop-portal;
          }
          {
            name = "xdg-permission-store";
            package = pkgs.xdg-desktop-portal;
          }
          {
            name = "xdg-desktop-portal-hyprland";
            package = config.wayland.windowManager.hyprland.finalPortalPackage;
          }
          {
            name = "xdg-desktop-portal-gtk";
            package = pkgs.xdg-desktop-portal-gtk;
          }
          {
            name = "xdg-desktop-portal-gnome";
            package = pkgs.xdg-desktop-portal-gnome;
          }
        ]
    );

    # Include GNOME's backend too so the existing Ubuntu session remains usable.
    xdg.portal = {
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
      ];
      config.hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      config.gnome.default = [
        "gnome"
        "gtk"
      ];
    };

    systemd.user.services.hyprland-polkit-agent = {
      Unit = {
        Description = "Polkit authentication agent for the Hyprland session";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };
    systemd.user.services.hyprland-mako = {
      Unit = {
        Description = "Notifications for the Hyprland session";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.mako}/bin/mako";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };

    services.mako.enable = true;
    services.mako.settings.default-timeout = 5000;
    services.swayidle = {
      enable = true;
      systemdTarget = "hyprland-session.target";
      events = [
        {
          event = "before-sleep";
          command = "${lockCommand}";
        }
      ];
      timeouts = [
        {
          timeout = 600;
          command = "${lockCommand}";
        }
      ];
    };
    programs.waybar = {
      enable = true;
      systemd = {
        enable = true;
        target = "hyprland-session.target";
      };
      settings.mainBar = {
        layer = "top";
        position = "top";
        modules-left = [ "hyprland/workspaces" ];
        modules-right = [
          "pulseaudio"
          "network"
          "battery"
          "clock"
        ];
        clock.format = "{:%a %d %b  %H:%M}";
        battery.format = "Battery {capacity}%";
        network = {
          format-wifi = "{essid}";
          format-ethernet = "Ethernet";
          format-disconnected = "Offline";
        };
        pulseaudio.format = "Volume {volume}%";
      };
      style = ''
        * { font-family: sans-serif; font-size: 13px; }
        window#waybar { background: #202020; color: #eeeeee; }
        #workspaces button { color: #eeeeee; }
        #battery, #clock, #network, #pulseaudio { padding: 0 10px; }
      '';
    };
  };
}
