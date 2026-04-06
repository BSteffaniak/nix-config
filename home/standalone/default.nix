# Standalone home-manager configuration for non-NixOS systems (Ubuntu, etc.)
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../modules
    ../common
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Enable XDG base directories
  xdg.enable = true;

  # Default options structure for myConfig
  # These can be overridden in host-specific configs
  options.myConfig = with lib; {
    # These options mirror the system-level ones but work standalone
  };

  # Sensible defaults for standalone usage
  config = {
    # Enable manual pages
    manual.manpages.enable = true;

    # Allow unfree packages (needed for some development tools)
    nixpkgs.config.allowUnfree = true;

    # Set up session variables
    home.sessionVariables = {
      # XDG directories
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };

    home.activation.warnLoginShellMismatch =
      lib.mkIf config.myConfig.shell.warnOnStandaloneLoginShellMismatch
        (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            desired_shell="${config.homeModules.shell.defaultShellPath}"
            username="$(id -un)"
            current_shell="$(awk -F: -v user="$username" '$1 == user { print $7 }' /etc/passwd)"
            desired_name="$(basename "$desired_shell")"
            current_name="$(basename "$current_shell")"

            if [ -n "$current_shell" ] && [ "$current_name" != "$desired_name" ]; then
              echo "[home-manager] Login shell mismatch detected for $username"
              echo "[home-manager] Current : $current_shell"
              echo "[home-manager] Desired : $desired_shell"

              if [ -f /etc/shells ] && ! grep -Fxq "$desired_shell" /etc/shells; then
                echo "[home-manager] '$desired_shell' is not listed in /etc/shells"
                echo "[home-manager] Add it to /etc/shells first, then run: chsh -s '$desired_shell' '$username'"
              else
                echo "[home-manager] Run: chsh -s '$desired_shell' '$username'"
              fi
            fi
          ''
        );
  };
}
