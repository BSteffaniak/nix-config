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
    development.rust.includeNightly = true;
    development.nodejs.enable = true;
    development.go.enable = true;
    development.python.enable = true;
    development.android.enable = false;
    development.devops.enable = true;
    development.podman.enable = true;
    development.openssl.enable = true;

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
    darwin.signal.enable = true;
    darwin.scrollReverser.enable = true;

    # Desktop environment
    desktop.aerospace.enable = true;
    desktop.sketchybar.enable = true;

    # Keyboard customization
    # Sledge replaces Hammerspoon. Sledge lives entirely in home-manager
    # (see hosts/macbook-air/home.nix), so only the Hammerspoon disable
    # lives here.
    darwin.hammerspoon.enable = false;
    darwin.security.touchId.enable = true;
    darwin.minecraft.enable = true;

    services.tailscale.enable = false;
  };

  # System packages specific to this host
  environment.systemPackages = with pkgs; [
    libiconv # Required for building chadthrottle on macOS
  ];

  # Networking
  networking.hostName = "Bradens-MacBook-Air";
  networking.computerName = "Braden's MacBook Air";

  # User configuration
  system.primaryUser = config.myConfig.username;

  # System version
  system.stateVersion = 6;

  # Platform
  nixpkgs.hostPlatform = "aarch64-darwin";
}
