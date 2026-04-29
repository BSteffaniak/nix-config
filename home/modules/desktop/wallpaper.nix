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

      wallpaper_dir=${escapeShellArg cfg.directory}
      market=${escapeShellArg cfg.market}
      resolution=${escapeShellArg cfg.resolution}
      retention_days=${toString cfg.retentionDays}
      set_desktop=${if cfg.setDesktop then "1" else "0"}

      mkdir -p "$wallpaper_dir"

      metadata_file="$wallpaper_dir/.bing-daily.json"
      metadata_tmp="$metadata_file.tmp"

      curl \
        --fail \
        --location \
        --silent \
        --show-error \
        --retry 3 \
        --connect-timeout 10 \
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

        if ! curl \
          --fail \
          --location \
          --silent \
          --show-error \
          --retry 3 \
          --connect-timeout 10 \
          "$image_url" \
          --output "$image_tmp"; then
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

          curl \
            --fail \
            --location \
            --silent \
            --show-error \
            --retry 3 \
            --connect-timeout 10 \
            "$fallback_image_url" \
            --output "$image_tmp"
        fi

        mv "$image_tmp" "$image_path"
      fi

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
          -name 'bing-*.jpg' \
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
      type = types.enum [ "bing-daily" ];
      default = "bing-daily";
      description = "Wallpaper source to use.";
    };

    directory = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/Pictures/Wallpapers/Bing Daily";
      description = "Directory where downloaded wallpapers are cached.";
    };

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
        assertion = cfg.source == "bing-daily";
        message = "myConfig.desktop.wallpaper.source currently supports only bing-daily.";
      }
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
