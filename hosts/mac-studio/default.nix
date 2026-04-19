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
    fullName = "Braden Steffaniak";
    homeManagerStateVersion = "24.11";

    # Development tools
    development.rust.enable = true;
    development.nodejs.enable = true;
    development.go.enable = true;
    development.python.enable = false;
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

    # Keyboard customization
    # Sledge replaces Hammerspoon. Sledge lives entirely in home-manager
    # (see hosts/mac-studio/home.nix), so only the Hammerspoon disable
    # lives here.
    darwin.hammerspoon.enable = false;
    darwin.security.touchId.enable = true;
    darwin.ollama.enable = true;

    services.tailscale.enable = true;
  };

  environment.systemPackages = [
    inputs.home-manager.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  # Networking
  networking.hostName = "Bradens-Mac-Studio";
  networking.computerName = "Braden's Mac Studio";

  # User configuration
  system.primaryUser = config.myConfig.username;

  # System version
  system.stateVersion = 6;

  # Platform - adjust this if your Mac Studio is Intel
  nixpkgs.hostPlatform = "aarch64-darwin"; # Change to "x86_64-darwin" if Intel
}
