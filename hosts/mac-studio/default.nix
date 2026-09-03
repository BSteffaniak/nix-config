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

  # Host-specific settings
  myConfig = {
    # Rust is configured in home.nix so it is only installed through
    # home-manager.
    development.nodejs.enable = true;
    development.go.enable = true;
    development.python.enable = true;
    development.android.enable = true;
    development.devops.enable = true;
    development.podman.enable = true;
    development.openssl.enable = true;
    development.java.enable = true;

    # Shell and editors
    shell.fish.enable = true;
    shell.bash.enable = true;
    shell.zsh.enable = true;
    shell.nushell.enable = true;
    shell.git.enable = true;
    shell.ssh.enable = true;
    shell.ssh.server.enable = true;
    editors.neovim.enable = true;
    editors.neovim.useNightly = true;

    # Darwin-specific
    darwin.homebrew.enable = true;
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

    # Desktop environment
    desktop.aerospace.enable = true;
    desktop.sketchybar.enable = true;

    # Keyboard customization (sledge) lives entirely in home-manager;
    # see hosts/mac-studio/home.nix for `myConfig.desktop.sledge.enable`.
    darwin.security.touchId.enable = true;
    darwin.ollama.enable = true;

    services.tailscale.enable = true;
  };

  environment.systemPackages = [
    inputs.home-manager.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  networking.computerName = "Braden's Mac Studio";
}
