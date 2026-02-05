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
    username = "braden";
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
    shell.git.enable = true;
    shell.ssh.enable = true;
    shell.ssh.server.enable = true;
    editors.neovim.enable = true;
    editors.neovim.useNightly = true;

    # Darwin-specific
    darwin.homebrew.enable = true;
    darwin.systemDefaults.enable = true;
    darwin.applications.enable = true;

    # Desktop environment
    desktop.aerospace.enable = true;
    desktop.sketchybar.enable = true;

    # Keyboard customization (Hammerspoon instead of Karabiner to avoid
    # virtual HID keyboard breaking Dvorak Ctrl key mappings)
    darwin.karabiner.enable = false;
    darwin.hammerspoon.enable = true;

    services.tailscale.enable = true;
  };

  # System packages specific to this host
  environment.systemPackages = with pkgs; [
    libiconv # Required for building chadthrottle on macOS
  ];

  # Networking
  networking.hostName = "Bradens-MacBook-Air";
  networking.computerName = "Braden's MacBook Air";

  # User configuration
  system.primaryUser = "braden";

  # System version
  system.stateVersion = 6;

  # Platform
  nixpkgs.hostPlatform = "aarch64-darwin";
}
