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
    username = "bsteffaniak";
    fullName = "Braden Steffaniak";
    homeManagerStateVersion = "24.11";

    # Development tools
    development.rust.enable = true;
    development.nodejs.enable = true;
    development.go.enable = true;
    development.python.enable = false;
    development.android.enable = false;
    development.devops.enable = true;
    development.podman.enable = true;
    development.openssl.enable = true;
    development.java.enable = true;

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
    darwin.googleChrome.enable = true;
    darwin.microsoftEdge.enable = true;

    # Desktop environment
    desktop.aerospace.enable = true;
    desktop.sketchybar.enable = true;

    # Keyboard customization (Hammerspoon - uses CGEventTap instead of
    # virtual HID keyboard, which avoids breaking Dvorak Ctrl key mappings)
    darwin.hammerspoon.enable = true;

    services.tailscale.enable = true;
  };

  environment.systemPackages = [
    inputs.home-manager.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  # Networking
  networking.hostName = "Bradens-Mac-Studio";
  networking.computerName = "Braden's Mac Studio";

  # User configuration
  system.primaryUser = "bsteffaniak";

  # System version
  system.stateVersion = 6;

  # Platform - adjust this if your Mac Studio is Intel
  nixpkgs.hostPlatform = "aarch64-darwin"; # Change to "x86_64-darwin" if Intel
}
