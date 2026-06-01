{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.wallpaper;

  inspiringWallpaper = pkgs.writeShellApplication {
    name = "inspiring-wallpaper";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      findutils
      gnused
      jq
    ];
    text = ''
      set -euo pipefail

      wallpaper_source=${escapeShellArg cfg.source}
      wallpaper_dir=${escapeShellArg cfg.directory}
      market=${escapeShellArg cfg.bing.market}
      resolution=${escapeShellArg cfg.bing.resolution}
      wallhaven_query=${escapeShellArg cfg.wallhaven.query}
      wallhaven_categories=${escapeShellArg cfg.wallhaven.categories}
      wallhaven_purity=${escapeShellArg cfg.wallhaven.purity}
      wallhaven_ratios=${escapeShellArg (concatStringsSep "," cfg.wallhaven.ratios)}
      wallhaven_atleast=${escapeShellArg cfg.wallhaven.atleast}
      wallhaven_sorting=${escapeShellArg cfg.wallhaven.sorting}
      retention_days=${toString cfg.retentionDays}
      set_desktop=${if cfg.setDesktop then "1" else "0"}

      mkdir -p "$wallpaper_dir"

      curl_common=(
        --fail
        --location
        --silent
        --show-error
        --retry 3
        --connect-timeout 10
      )

      image_path=""

      fetch_wallhaven() {
        local metadata_file metadata_tmp encoded_query api_url count selected_index
        local wallhaven_id image_url extension image_tmp

        metadata_file="$wallpaper_dir/.wallhaven.json"
        metadata_tmp="$metadata_file.tmp"
        encoded_query="$(printf '%s' "$wallhaven_query" | jq -sRr @uri)"
        api_url="https://wallhaven.cc/api/v1/search?q=$encoded_query&categories=$wallhaven_categories&purity=$wallhaven_purity&sorting=$wallhaven_sorting&ratios=$wallhaven_ratios&atleast=$wallhaven_atleast"

        curl "''${curl_common[@]}" "$api_url" --output "$metadata_tmp"
        mv "$metadata_tmp" "$metadata_file"

        count="$(jq '.data | length' "$metadata_file")"
        if [[ "$count" -lt 1 ]]; then
          echo "Wallhaven returned no wallpapers for query: $wallhaven_query" >&2
          exit 1
        fi

        selected_index=0
        if [[ "$count" -gt 1 ]]; then
          selected_index="$((RANDOM % count))"
        fi

        wallhaven_id="$(jq -r --argjson index "$selected_index" '.data[$index].id // empty' "$metadata_file")"
        image_url="$(jq -r --argjson index "$selected_index" '.data[$index].path // empty' "$metadata_file")"

        if [[ -z "$wallhaven_id" || -z "$image_url" ]]; then
          echo "Wallhaven metadata did not include an image URL." >&2
          exit 1
        fi

        extension="''${image_url##*.}"
        extension="$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')"
        case "$extension" in
          jpg | jpeg | png) ;;
          *) extension="jpg" ;;
        esac

        image_path="$wallpaper_dir/wallhaven-$wallhaven_id.$extension"
        image_tmp="$image_path.tmp"

        if [[ ! -s "$image_path" ]]; then
          curl "''${curl_common[@]}" "$image_url" --output "$image_tmp"
          mv "$image_tmp" "$image_path"
        fi
      }

      fetch_bing_daily() {
        local metadata_file metadata_tmp startdate title urlbase fallback_url safe_title
        local image_tmp image_url fallback_image_url

        metadata_file="$wallpaper_dir/.bing-daily.json"
        metadata_tmp="$metadata_file.tmp"

        curl \
          "''${curl_common[@]}" \
          "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$market" \
          --output "$metadata_tmp"
        mv "$metadata_tmp" "$metadata_file"

        startdate="$(jq -r '.images[0].startdate // empty' "$metadata_file")"
        title="$(jq -r '.images[0].title // .images[0].copyright // "bing daily"' "$metadata_file")"
        urlbase="$(jq -r '.images[0].urlbase // empty' "$metadata_file")"
        fallback_url="$(jq -r '.images[0].url // empty' "$metadata_file")"

        if [[ -z "$startdate" ]]; then
          startdate="$(date +%Y%m%d)"
        fi

        safe_title="$(printf '%s' "$title" \
          | tr -cs '[:alnum:]._-' '-' \
          | sed 's/^-//; s/-$//; s/--*/-/g' \
          | cut -c1-80)"
        if [[ -z "$safe_title" ]]; then
          safe_title="bing-daily"
        fi

        image_path="$wallpaper_dir/bing-$startdate-$safe_title.jpg"
        image_tmp="$image_path.tmp"

        if [[ ! -s "$image_path" ]]; then
          if [[ -n "$urlbase" ]]; then
            image_url="https://www.bing.com''${urlbase}_''${resolution}.jpg"
          elif [[ "$fallback_url" == http* ]]; then
            image_url="$fallback_url"
          else
            image_url="https://www.bing.com$fallback_url"
          fi

          if ! curl "''${curl_common[@]}" "$image_url" --output "$image_tmp"; then
            rm -f "$image_tmp"

            if [[ -z "$fallback_url" ]]; then
              echo "Bing metadata did not include a fallback image URL." >&2
              exit 1
            fi

            if [[ "$fallback_url" == http* ]]; then
              fallback_image_url="$fallback_url"
            else
              fallback_image_url="https://www.bing.com$fallback_url"
            fi

            curl "''${curl_common[@]}" "$fallback_image_url" --output "$image_tmp"
          fi

          mv "$image_tmp" "$image_path"
        fi
      }

      case "$wallpaper_source" in
        wallhaven)
          fetch_wallhaven
          ;;
        bing-daily)
          fetch_bing_daily
          ;;
        *)
          echo "Unsupported wallpaper source: $wallpaper_source" >&2
          exit 1
          ;;
      esac

      if [[ "$set_desktop" == "1" ]]; then
        /usr/bin/osascript - "$image_path" <<'APPLESCRIPT'
      on run argv
        set imagePath to item 1 of argv
        tell application "System Events"
          repeat with aDesktop in desktops
            set picture of aDesktop to imagePath
          end repeat
        end tell
      end run
      APPLESCRIPT
      fi

      if [[ "$retention_days" -gt 0 ]]; then
        find "$wallpaper_dir" \
          -maxdepth 1 \
          -type f \
          \( -name 'wallhaven-*' -o -name 'bing-*.jpg' \) \
          -mtime +"$retention_days" \
          -delete
      fi

      echo "$image_path"
    '';
  };
in
{
  options.myConfig.desktop.wallpaper = {
    enable = mkEnableOption "inspiring macOS wallpapers";

    source = mkOption {
      type = types.enum [
        "wallhaven"
        "bing-daily"
      ];
      default = "wallhaven";
      description = "Wallpaper source to use.";
    };

    directory = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/Pictures/Wallpapers/Wallhaven";
      description = "Directory where downloaded wallpapers are cached.";
    };

    wallhaven = {
      query = mkOption {
        type = types.str;
        default = "nature landscape mountains forest ocean -flag -flags -politics -political -logo -text -weapon -war";
        description = "Wallhaven search query. Negative terms are used to avoid noisy or political imagery.";
      };

      categories = mkOption {
        type = types.enum [
          "100"
          "101"
          "110"
          "111"
        ];
        default = "100";
        description = "Wallhaven category mask. Default is general wallpapers only.";
      };

      purity = mkOption {
        type = types.enum [
          "100"
          "110"
        ];
        default = "100";
        description = "Wallhaven purity mask. Default is SFW only.";
      };

      ratios = mkOption {
        type = types.listOf types.str;
        default = [
          "16x9"
          "16x10"
        ];
        description = "Preferred Wallhaven aspect ratios.";
      };

      atleast = mkOption {
        type = types.str;
        default = "3840x2160";
        description = "Minimum Wallhaven image resolution.";
      };

      sorting = mkOption {
        type = types.enum [
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
      market = mkOption {
        type = types.str;
        default = "en-US";
        description = "Bing image market/locale used for the daily wallpaper feed.";
      };

      resolution = mkOption {
        type = types.enum [
          "UHD"
          "1920x1080"
          "1366x768"
        ];
        default = "UHD";
        description = "Preferred Bing image resolution. Falls back to Bing's default URL if unavailable.";
      };
    };

    refreshHour = mkOption {
      type = types.ints.between 0 23;
      default = 7;
      description = "Hour of day when launchd refreshes the wallpaper.";
    };

    refreshMinute = mkOption {
      type = types.ints.between 0 59;
      default = 15;
      description = "Minute of the hour when launchd refreshes the wallpaper.";
    };

    retentionDays = mkOption {
      type = types.ints.unsigned;
      default = 90;
      description = "Delete cached wallpapers older than this many days. Set to 0 to keep all.";
    };

    setDesktop = mkOption {
      type = types.bool;
      default = true;
      description = "Set the downloaded image as the desktop wallpaper.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "myConfig.desktop.wallpaper is currently only supported on macOS.";
      }
    ];

    home.packages = [ inspiringWallpaper ];

    launchd.agents.inspiring-wallpaper = {
      enable = true;
      config = {
        Label = "com.braden.inspiring-wallpaper";
        ProgramArguments = [ "${inspiringWallpaper}/bin/inspiring-wallpaper" ];
        RunAtLoad = true;
        StartCalendarInterval = {
          Hour = cfg.refreshHour;
          Minute = cfg.refreshMinute;
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/inspiring-wallpaper.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/inspiring-wallpaper.err.log";
      };
    };
  };
}
