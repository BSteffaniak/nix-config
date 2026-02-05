{
  config,
  lib,
  pkgs,
  osConfig,
  inputs ? { },
  ...
}:

{
  imports = [
    ../common
    ../modules
  ];

  home.username = osConfig.myConfig.username;
  home.homeDirectory = lib.mkForce "/Users/${osConfig.myConfig.username}";

  # State version should match the Darwin release when home-manager was first used
  # Use the homeManagerStateVersion from host config
  home.stateVersion = osConfig.myConfig.homeManagerStateVersion;

  # Mirror system configuration to home-manager modules
  myConfig = {
    # Development tools
    development.rust.enable = osConfig.myConfig.development.rust.enable or false;
    development.rust.includeNightly = osConfig.myConfig.development.rust.includeNightly or false;
    development.nodejs.enable = osConfig.myConfig.development.nodejs.enable or false;
    development.go.enable = osConfig.myConfig.development.go.enable or false;
    development.python.enable = osConfig.myConfig.development.python.enable or false;
    development.java.enable = osConfig.myConfig.development.java.enable or false;
    development.openssl.enable = osConfig.myConfig.development.openssl.enable or false;

    # Containers - Podman works on macOS!
    containers.podman.enable = osConfig.myConfig.development.podman.enable or false;

    # DevOps tools
    devops.kubernetes.enable = osConfig.myConfig.development.devops.enable or false;
    devops.cloud.enable = osConfig.myConfig.development.devops.enable or false;
    devops.infrastructure.enable = osConfig.myConfig.development.devops.enable or false;

    # Shell
    shell.fish.enable = osConfig.myConfig.shell.fish.enable or false;
    shell.git.enable = osConfig.myConfig.shell.git.enable or false;
    shell.ssh.enable = osConfig.myConfig.shell.ssh.enable or false;

    # Editors
    editors.neovim.enable = osConfig.myConfig.editors.neovim.enable or false;
    editors.neovim.useNightly = osConfig.myConfig.editors.neovim.useNightly or false;

    # Desktop (Karabiner, Hammerspoon)
    desktop.karabiner.enable = osConfig.myConfig.darwin.karabiner.enable or false;
    desktop.hammerspoon.enable = osConfig.myConfig.darwin.hammerspoon.enable or false;
  };

  # Pass inputs to modules that need them
  _module.args = {
    inherit inputs;
  };

  # Darwin-specific packages
  home.packages = with pkgs; [
    # Add macOS-specific packages here
  ];
}
