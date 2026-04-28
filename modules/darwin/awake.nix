# Privileged macOS backend for the `stay-awake` Home Manager command.
#
# The user command writes requests into a state directory. This LaunchDaemon
# performs the privileged `pmset disablesleep` toggles and automatically restores
# normal sleep behavior after a closed-lid session ends.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.awake;
  username = config.myConfig.username;
  homeDir = "/Users/${username}";
  stateDir = "${homeDir}/.local/state/stay-awake";

  daemon = pkgs.writeShellScriptBin "stay-awake-darwin-daemon" ''
    set -eu

    user_name="${username}"
    state_dir="${stateDir}"
    request_file="$state_dir/request"
    status_file="$state_dir/status"
    active_file="$state_dir/active"
    seen_closed_file="$state_dir/seen-closed"

    ensure_state_dir() {
      /bin/mkdir -p "$state_dir"
      /usr/sbin/chown "$user_name" "${homeDir}/.local" "${homeDir}/.local/state" "$state_dir" 2>/dev/null || true
      /bin/chmod 700 "$state_dir" 2>/dev/null || true
    }

    now() {
      /bin/date '+%Y-%m-%d %H:%M:%S %Z'
    }

    write_status() {
      printf '%s\nupdated: %s\n' "$1" "$(now)" > "$status_file"
      /usr/sbin/chown "$user_name" "$status_file" 2>/dev/null || true
    }

    lid_state() {
      if /usr/sbin/ioreg -r -k AppleClamshellState -d 4 2>/dev/null | /usr/bin/grep -q '"AppleClamshellState" = Yes'; then
        echo closed
      else
        echo open
      fi
    }

    enable_awake() {
      /usr/bin/pmset -a disablesleep 1
      /bin/date > "$active_file"
      /bin/rm -f "$seen_closed_file"
      /usr/sbin/chown "$user_name" "$active_file" 2>/dev/null || true
      write_status "active: armed; close lid to start closed-lid session"
    }

    disable_awake() {
      reason="$1"
      /usr/bin/pmset -a disablesleep 0
      /bin/rm -f "$active_file" "$seen_closed_file" "$request_file"
      write_status "inactive: $reason; normal lid/sleep behavior restored"
    }

    handle_request() {
      if [ ! -f "$request_file" ]; then
        return 0
      fi

      request="$(/bin/cat "$request_file" 2>/dev/null || true)"
      request="$(printf '%s' "$request" | /usr/bin/head -n 1 | /usr/bin/tr -d '[:space:]')"

      case "$request" in
        on)
          /bin/rm -f "$request_file"
          enable_awake
          ;;
        off)
          disable_awake "manual off"
          ;;
        *)
          /bin/rm -f "$request_file"
          write_status "inactive: ignored unknown request '$request'"
          ;;
      esac
    }

    ensure_state_dir
    if [ ! -f "$active_file" ]; then
      write_status "inactive: normal lid/sleep behavior active"
    fi

    while true; do
      ensure_state_dir
      handle_request

      if [ -f "$active_file" ]; then
        current_lid_state="$(lid_state)"

        case "$current_lid_state" in
          closed)
            /usr/bin/touch "$seen_closed_file"
            /usr/sbin/chown "$user_name" "$seen_closed_file" 2>/dev/null || true
            write_status "active: lid closed; sleep disabled; will restore when lid opens"
            ;;
          open)
            if [ -f "$seen_closed_file" ]; then
              disable_awake "lid opened"
            else
              write_status "active: armed; close lid to start closed-lid session"
            fi
            ;;
          *)
            write_status "active: lid state unknown; run 'stay-awake off' to restore"
            ;;
        esac
      fi

      /bin/sleep 2
    done
  '';
in
{
  options.myConfig.darwin.awake = {
    enable = mkEnableOption "privileged stay-awake backend for one-shot closed-lid sessions";
  };

  config = mkIf cfg.enable {
    launchd.daemons.stay-awake = {
      serviceConfig = {
        Label = "dev.braden.stay-awake";
        ProgramArguments = [
          "${daemon}/bin/stay-awake-darwin-daemon"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/var/log/stay-awake.log";
        StandardErrorPath = "/var/log/stay-awake.log";
      };
    };
  };
}
