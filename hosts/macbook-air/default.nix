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
    services.tailscale.enable = false;

    # Darwin-specific
    darwin.homebrew.enable = true;
    darwin.awake.enable = true;
    darwin.systemDefaults.enable = true;
    darwin.systemDefaults.darkMode = true;
    darwin.applications.enable = true;
    darwin.ghostty.enable = true;
    darwin.googleChrome.enable = true;
    darwin.hex.enable = true;
    darwin.istatMenus.enable = true;
    darwin.microsoftEdge.enable = true;
    darwin.roon.enable = true;
    darwin.signal.enable = true;
    darwin.scrollReverser.enable = true;
    darwin.security.touchId.enable = true;
    darwin.minecraft.enable = true;

    # Desktop environment
    desktop.aerospace.enable = true;
    desktop.sketchybar.enable = true;
  };

  # System packages specific to this host
  environment.systemPackages = with pkgs; [
    libiconv # Required for building chadthrottle on macOS
  ];

  networking.computerName = "Braden's MacBook Air";
}
