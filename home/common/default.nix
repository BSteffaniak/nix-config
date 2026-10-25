# Shared home-manager configuration for every host.
{ config, lib, ... }:

{
  imports = [
    ../modules
    (import ../../lib/generated-files-module.nix {
      fileOption = [
        "home"
        "file"
      ];
      defaultRepositoryPath = config: "${config.home.homeDirectory}/.config/nix";
      noticeTarget = ".config/nix-managed-files.txt";
    })
  ];

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # User-facing tools installed on every managed host.
  myConfig.cliTools.utilities.sendsafely.enable = true;

  # External host: Windows is not built by this flake, but advertises its
  # existing computer name through Bonjour. Keep its alias portable too.
  myConfig.shell.ssh.matchBlocks = lib.mkIf config.myConfig.shell.ssh.fleetAliases.enable {
    windows-desktop = {
      hostname = lib.mkDefault "desktop-tko79vi.local";
      user = lib.mkDefault "brade";
    };
  };

  myConfig.shell.contrib = {
    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.npm-packages/bin"
      "$HOME/.bun/bin"
    ];

    # POSIX shell initialization shared between bash and zsh.
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
