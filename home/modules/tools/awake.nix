# Runtime sleep/lid-sleep control.
#
# Provides a manual `stay-awake` command. It is intentionally a runtime toggle
# rather than a permanent power-management default.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.tools.awake;

  darwinStateDir = "${config.home.homeDirectory}/.local/state/stay-awake";

  stayAwake = pkgs.writeShellScriptBin "stay-awake" ''
    set -euo pipefail

    command="''${1:-status}"

    usage() {
      cat <<'USAGE'
    Usage: stay-awake [on|off|status]

      on      Keep the laptop awake with the lid closed until the lid is opened again
      off     Restore normal lid/sleep behavior immediately
      status  Show current stay-awake state

    Notes:
      - macOS requires myConfig.darwin.awake.enable for privileged pmset handling.
      - Linux uses the stay-awake-lid user systemd service.
    USAGE
    }

    os_name="$(uname -s)"

    if [[ "$os_name" == "Darwin" ]]; then
      state_dir="${darwinStateDir}"
      request_file="$state_dir/request"
      status_file="$state_dir/status"

      ensure_state_dir() {
        if [[ ! -d "$state_dir" ]]; then
          echo "stay-awake daemon has not initialized $state_dir yet." >&2
          echo "Run darwin-rebuild after enabling myConfig.darwin.awake.enable, or wait a few seconds and retry." >&2
          exit 1
        fi
      }

      send_request() {
        local request="$1"
        ensure_state_dir
        printf '%s\n' "$request" > "$request_file"

        # The root LaunchDaemon polls this file. Wait briefly so the command
        # only returns once the request was observed in the common case.
        for _ in {1..30}; do
          if [[ ! -e "$request_file" ]]; then
            return 0
          fi
          sleep 0.2
        done

        echo "request queued; stay-awake daemon should apply it shortly" >&2
      }

      case "$command" in
        on)
          send_request on
          echo "stay-awake armed: sleep is disabled until you open the lid again or run 'stay-awake off'."
          ;;
        off)
          send_request off
          echo "stay-awake disabled: normal lid/sleep behavior restored."
          ;;
        status)
          if [[ -f "$status_file" ]]; then
            cat "$status_file"
          else
            echo "stay-awake status unavailable; daemon may not be initialized."
          fi
          if command -v pmset >/dev/null 2>&1; then
            pmset -g | grep -E '^ *disablesleep' || true
          fi
          ;;
        -h|--help|help)
          usage
          ;;
        *)
          usage >&2
          exit 2
          ;;
      esac

      exit 0
    fi

    if [[ "$os_name" == "Linux" ]]; then
      unit="stay-awake-lid.service"

      require_systemctl() {
        if ! command -v systemctl >/dev/null 2>&1; then
          echo "systemctl is required for stay-awake on Linux" >&2
          exit 1
        fi
      }

      case "$command" in
        on)
          require_systemctl
          systemctl --user start "$unit"
          echo "stay-awake armed: sleep/lid handling is inhibited until you open the lid again or run 'stay-awake off'."
          ;;
        off)
          require_systemctl
          systemctl --user stop "$unit"
          echo "stay-awake disabled: normal lid/sleep behavior restored."
          ;;
        status)
          require_systemctl
          if systemctl --user is-active --quiet "$unit"; then
            echo "stay-awake active"
          else
            echo "stay-awake inactive"
          fi
          systemctl --user --no-pager --plain status "$unit" 2>/dev/null | sed -n '1,12p' || true
          ;;
        -h|--help|help)
          usage
          ;;
        *)
          usage >&2
          exit 2
          ;;
      esac

      exit 0
    fi

    echo "stay-awake is unsupported on $os_name" >&2
    exit 1
  '';

  linuxWatcher = pkgs.writeShellScriptBin "stay-awake-linux-watch" ''
    set -euo pipefail

    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.systemd
      ]
    }:$PATH

    state_dir="$HOME/.local/state/stay-awake"
    mkdir -p "$state_dir"

    lid_state() {
      local f
      for f in /proc/acpi/button/lid/*/state; do
        if [[ -r "$f" ]]; then
          awk '{ print tolower($2) }' "$f"
          return 0
        fi
      done

      echo "unknown"
    }

    watch_lid() {
      local seen_closed=0
      local current

      printf 'active: waiting for lid close\n' > "$state_dir/status"

      while true; do
        current="$(lid_state)"

        case "$current" in
          closed)
            seen_closed=1
            printf 'active: lid closed; will restore on open\n' > "$state_dir/status"
            ;;
          open)
            if [[ "$seen_closed" == 1 ]]; then
              printf 'inactive: lid opened; inhibitor released\n' > "$state_dir/status"
              exit 0
            fi
            printf 'active: armed; close lid to start closed-lid session\n' > "$state_dir/status"
            ;;
          *)
            printf 'active: lid state unknown; stop with stay-awake off\n' > "$state_dir/status"
            ;;
        esac

        sleep 2
      done
    }

    if [[ "''${1:-}" == "--watch" ]]; then
      watch_lid
      exit 0
    fi

    exec systemd-inhibit \
      --what=sleep:handle-lid-switch \
      --mode=block \
      --why="stay-awake closed-lid session" \
      "$0" --watch
  '';
in
{
  options.myConfig.tools.awake = {
    enable = mkEnableOption "runtime stay-awake command for manual lid/sleep control";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [ stayAwake ];
    }

    (mkIf pkgs.stdenv.isLinux {
      systemd.user.services.stay-awake-lid = {
        Unit = {
          Description = "Stay awake for one closed-lid session";
          Documentation = [ "man:systemd-inhibit(1)" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${linuxWatcher}/bin/stay-awake-linux-watch";
          Restart = "no";
        };
      };
    })
  ]);
}
