{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages =
    with pkgs;
    [
      # Password management
      bitwarden-desktop

      # Development tools
      gh-dash
      natscli
      aider-chat

      # Cloud tools
      flyctl

      # Media tools
      mediainfo
      flac

      # Code tools
      unstable.claude-code
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Linux-only packages
      unstable.ghostty
      hyprshot
      brightnessctl
      libinput
      evtest
      qalculate-gtk
      kdePackages.elisa
    ];
}
