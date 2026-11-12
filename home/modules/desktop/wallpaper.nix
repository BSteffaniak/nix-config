{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig.desktop.wallpaper;
  isDarwin = pkgs.stdenv.isDarwin;
  settings = pkgs.writeText "wallpaper-settings.json" (
    builtins.toJSON {
      inherit (cfg)
        source
        directory
        wallhaven
        bing
        retentionDays
        maxImages
        setDesktop
        ;
      platform = if isDarwin then "darwin" else "linux";
      stateDirectory =
        if isDarwin then
          "${config.home.homeDirectory}/Library/Application Support/inspiring-wallpaper"
        else
          "${config.xdg.stateHome}/inspiring-wallpaper";
    }
  );
  inspiringWallpaper = pkgs.writeShellApplication {
    name = "inspiring-wallpaper";
    runtimeInputs = [
      pkgs.python3
      pkgs.curl
    ]
    ++ lib.optionals (!isDarwin) [
      pkgs.waypaper
      pkgs.swww
    ];
    text = ''
      exec python3 ${../../../configs/waypaper/wallpaper.py} --config ${settings} "$@"
    '';
  };
  command = "${inspiringWallpaper}/bin/inspiring-wallpaper";
  displayWatcher = pkgs.writeShellApplication {
    name = "inspiring-wallpaper-display-watcher";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      fingerprint_displays() {
        /usr/sbin/ioreg -r -c AppleDisplayConnectionManager -l -w0 2>/dev/null | cksum || true
      }
      previous_fingerprint="$(fingerprint_displays)"
      while true; do
        sleep ${toString cfg.monitorWatcher.pollSeconds}
        current_fingerprint="$(fingerprint_displays)"
        if [[ -n "$current_fingerprint" && "$current_fingerprint" != "$previous_fingerprint" ]]; then
          previous_fingerprint="$current_fingerprint"
          # Spaces for newly connected displays may take a few seconds to appear.
          for delay in 2 8 20; do
            sleep "$delay"
            ${command} --apply-current || true
          done
        fi
      done
    '';
  };
  sessionStartup = pkgs.writeShellApplication {
    name = "start-wallpaper-session";
    runtimeInputs = [
      pkgs.systemd
      pkgs.swww
      pkgs.coreutils
    ];
    text = ''
      systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP
      if ! swww query >/dev/null 2>&1; then
        swww-daemon &
      fi
      for attempt in {1..50}; do
        if swww query >/dev/null 2>&1; then
          systemctl --user restart inspiring-wallpaper.timer
          exit 0
        fi
        sleep 0.2
      done
      echo "swww did not become ready" >&2
      exit 1
    '';
  };
  launchAgent = name: args: schedule: {
    enable = true;
    config = {
      Label = "com.braden.${name}";
      ProgramArguments = [ command ] ++ args;
      RunAtLoad = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/${name}.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/${name}.err.log";
    }
    // schedule;
  };
in
{
  options.myConfig.desktop.wallpaper = {
    enable = lib.mkEnableOption "cached wallpaper downloads and shuffle rotation";
    source = lib.mkOption {
      type = lib.types.enum [
        "wallhaven"
        "bing-daily"
      ];
      default = "wallhaven";
      description = "Source used to replenish the local wallpaper collection.";
    };
    directory = lib.mkOption {
      type = lib.types.str;
      default =
        if isDarwin then
          "${config.home.homeDirectory}/Pictures/Wallpapers/Wallhaven"
        else
          "${config.home.homeDirectory}/Pictures/wallpapers";
      description = "Local wallpaper collection, including any user-supplied JPEG/PNG images.";
    };
    rotationMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 180;
      description = "Minutes between local wallpaper changes; downloading is scheduled separately.";
    };
    wallhaven = {
      requiredTagGroups = lib.mkOption {
        type = lib.types.listOf (lib.types.listOf lib.types.str);
        default = [
          [
            "photography"
            "landscape photography"
            "nature photography"
          ]
          [
            "nature"
            "landscape"
            "landscapes"
            "mountains"
            "forest"
            "forests"
            "ocean"
            "sea"
            "beach"
            "lake"
            "waterfall"
          ]
        ];
        description = "Require at least one exact tag from each group before a downloaded image can rotate. Metadata must be verified, even for existing downloads.";
      };
      excludedTags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "anime"
          "manga"
          "illustration"
          "digital art"
          "digital painting"
          "artwork"
          "drawing"
          "painting"
          "concept art"
          "fantasy art"
          "3d"
          "cgi"
          "render"
          "ai art"
          "ai generated"
          "ai-generated"
          "generative art"
          "video game"
          "videogame"
          "character"
          "people"
          "person"
          "portrait"
          "women"
          "woman"
          "girls"
          "girl"
          "men"
          "man"
          "boy"
        ];
        description = "Reject tags containing these words/phrases (word-boundary matching). Tagging is not a visual guarantee.";
      };
      excludedTagCategories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "Anime & Manga"
          "People"
          "Fictional Characters"
          "Games"
        ];
        description = "Reject images with any tag belonging to these Wallhaven tag categories.";
      };
      query = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional single search overriding queries (compatibility with existing host overrides).";
      };
      queries = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default =
          map
            (
              topic:
              "${topic} photography -anime -people -illustration -\"digital art\" -\"video games\" -flag -flags -politics -political -logo -text -weapon -war"
            )
            [
              "landscape"
              "mountains"
              "forest"
              "ocean"
              "nature"
            ];
        description = "Independent searches for a varied nature collection, rather than one restrictive combined search.";
      };
      imagesPerQuery = lib.mkOption {
        type = lib.types.ints.between 1 24;
        default = 4;
        description = "Maximum images downloaded per search during the daily replenishment.";
      };
      categories = lib.mkOption {
        type = lib.types.enum [
          "100"
          "101"
          "110"
          "111"
        ];
        default = "100";
        description = "Wallhaven category mask (general wallpapers by default).";
      };
      purity = lib.mkOption {
        type = lib.types.enum [
          "100"
          "110"
        ];
        default = "100";
        description = "Wallhaven purity mask (SFW by default).";
      };
      ratios = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "16x9"
          "16x10"
        ];
        description = "Preferred Wallhaven aspect ratios.";
      };
      atleast = lib.mkOption {
        type = lib.types.str;
        default = "3840x2160";
        description = "Minimum Wallhaven image resolution.";
      };
      sorting = lib.mkOption {
        type = lib.types.enum [
          "random"
          "relevance"
          "date_added"
          "views"
          "favorites"
          "toplist"
        ];
        default = "random";
        description = "Wallhaven result sorting mode.";
      };
    };
    bing = {
      market = lib.mkOption {
        type = lib.types.str;
        default = "en-US";
        description = "Bing daily image market/locale.";
      };
      resolution = lib.mkOption {
        type = lib.types.enum [
          "UHD"
          "1920x1080"
          "1366x768"
        ];
        default = "UHD";
        description = "Preferred Bing image resolution, with fallback to its default URL.";
      };
    };
    refreshHour = lib.mkOption {
      type = lib.types.ints.between 0 23;
      default = 7;
      description = "Hour of daily cache replenishment.";
    };
    refreshMinute = lib.mkOption {
      type = lib.types.ints.between 0 59;
      default = 15;
      description = "Minute of daily cache replenishment.";
    };
    retentionDays = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 90;
      description = "Age limit for downloaded images; 0 disables age-based cleanup.";
    };
    maxImages = lib.mkOption {
      type = lib.types.ints.positive;
      default = 200;
      description = "Maximum downloaded images retained (user-supplied images are never pruned).";
    };
    setDesktop = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply the selected wallpaper to the desktop.";
    };
    monitorWatcher = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Reapply the current wallpaper when macOS display topology changes.";
      };
      pollSeconds = lib.mkOption {
        type = lib.types.ints.between 1 3600;
        default = 15;
        description = "Seconds between macOS display topology checks.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.wallhaven.query != "" || cfg.wallhaven.queries != [ ];
            message = "Wallpaper replenishment requires at least one search query.";
          }
        ];
        home.packages = [ inspiringWallpaper ] ++ lib.optional (!isDarwin) sessionStartup;
      }
      (lib.mkIf isDarwin {
        launchd.agents.inspiring-wallpaper = launchAgent "inspiring-wallpaper" [ "--rotate" ] {
          StartInterval = cfg.rotationMinutes * 60;
        };
        launchd.agents.inspiring-wallpaper-download =
          launchAgent "inspiring-wallpaper-download" [ "--refresh" ]
            {
              StartCalendarInterval = {
                Hour = cfg.refreshHour;
                Minute = cfg.refreshMinute;
              };
            };
        launchd.agents.inspiring-wallpaper-display-watcher = lib.mkIf cfg.monitorWatcher.enable {
          enable = true;
          config = {
            Label = "com.braden.inspiring-wallpaper-display-watcher";
            ProgramArguments = [ "${displayWatcher}/bin/inspiring-wallpaper-display-watcher" ];
            RunAtLoad = true;
            KeepAlive = {
              Crashed = true;
              SuccessfulExit = false;
            };
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/inspiring-wallpaper-display-watcher.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/inspiring-wallpaper-display-watcher.err.log";
          };
        };
      })
      (lib.mkIf (!isDarwin) {
        systemd.user.services.inspiring-wallpaper = {
          Unit = {
            Description = "Rotate cached desktop wallpaper";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${command} --rotate";
          };
        };
        systemd.user.timers.inspiring-wallpaper = {
          Unit = {
            Description = "Shuffle cached wallpapers every ${toString cfg.rotationMinutes} minutes";
            PartOf = [ "graphical-session.target" ];
          };
          Timer = {
            OnActiveSec = "30s";
            OnUnitActiveSec = "${toString cfg.rotationMinutes}min";
            Unit = "inspiring-wallpaper.service";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
        systemd.user.services.inspiring-wallpaper-download = {
          Unit.Description = "Replenish wallpaper collection";
          Service = {
            Type = "oneshot";
            ExecStart = "${command} --refresh";
          };
        };
        systemd.user.timers.inspiring-wallpaper-download = {
          Unit.Description = "Download fresh wallpapers daily";
          Timer = {
            OnCalendar = "*-*-* ${lib.fixedWidthNumber 2 cfg.refreshHour}:${lib.fixedWidthNumber 2 cfg.refreshMinute}:00";
            OnActiveSec = "10s";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      })
    ]
  );
}
