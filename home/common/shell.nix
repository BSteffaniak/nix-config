{
  config,
  lib,
  pkgs,
  ...
}:

let
  sessionVariables = {
    # Add common session variables here
  };
in
{
  programs.bash = {
    enable = true;
    initExtra = ''
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"

      # Source rc-files if they exist
      if [ -f ~/.rc-files/env.sh ]; then
        . ~/.rc-files/env.sh
      fi

      # Flat
      if [ -f ~/.flat/env ]; then
        . ~/.flat/env
      fi
    '';
    sessionVariables = sessionVariables;
  };

  home.sessionVariables = sessionVariables;

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-packages/bin"
    "$HOME/.bun/bin"
  ];
}
