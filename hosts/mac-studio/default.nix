{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/common
    ../../modules/darwin
  ];

  # Host-specific system settings. User tools live in home.nix.
  myConfig = {
    # Login shells
    shell.fish.enable = true;
    shell.bash.enable = true;
    shell.zsh.enable = true;
    shell.nushell.enable = true;

    services.sshd.enable = true;
    services.tailscale.enable = true;

    # Darwin-specific
    darwin.homebrew.enable = true;
    darwin.androidStudio.enable = true;
    darwin.systemDefaults.enable = true;
    darwin.systemDefaults.darkMode = true;
    darwin.applications.enable = true;
    darwin.ghostty.enable = true;
    darwin.googleChrome.enable = true;
    darwin.hex.enable = true;
    darwin.istatMenus.enable = true;
    darwin.microsoftEdge.enable = true;
    darwin.roon.enable = true;
    darwin.scrollReverser.enable = true;
    darwin.scrollReverser.reverseVertical = false;
    darwin.security.touchId.enable = true;
    darwin.ollama.enable = true;

    # Desktop environment
    desktop.aerospace.enable = true;
    desktop.sketchybar.enable = true;
  };

  environment.systemPackages = [
    inputs.home-manager.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  networking.computerName = "Braden's Mac Studio";
}
