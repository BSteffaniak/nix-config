{
  ...
}:

{
  homeModules.shell.shared.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-packages/bin"
    "$HOME/.bun/bin"
  ];

  # POSIX shell initialization shared between bash and zsh.
  homeModules.shell.shared = {
    bashInit = ''
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi

      if [ -f ~/.rc-files/env.sh ]; then
        . ~/.rc-files/env.sh
      fi

      if [ -f ~/.flat/env ]; then
        . ~/.flat/env
      fi
    '';

    zshInit = ''
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi

      if [ -f ~/.rc-files/env.sh ]; then
        . ~/.rc-files/env.sh
      fi

      if [ -f ~/.flat/env ]; then
        . ~/.flat/env
      fi
    '';

    fishInit = ''
      if test -f ~/.rc-files/env.sh
        if functions -q bass
          bass source ~/.rc-files/env.sh
        end
      end

      if test -f ~/.flat/env
        if functions -q bass
          bass source ~/.flat/env
        end
      end
    '';
  };
}
