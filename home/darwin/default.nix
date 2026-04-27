{
  lib,
  myLib,
  osConfig,
  inputs ? { },
  ...
}:

let
  defaultShell = lib.attrByPath [
    "defaults"
    "shell"
    "default"
  ] "nushell" myLib;
in
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
    development.android.enable = osConfig.myConfig.development.android.enable or false;
    development.java.enable = osConfig.myConfig.development.java.enable or false;
    development.openssl.enable = osConfig.myConfig.development.openssl.enable or false;

    # Containers - Podman works on macOS!
    containers.podman.enable = osConfig.myConfig.development.podman.enable or false;
    containers.tools.enable = osConfig.myConfig.development.devops.enable or false;

    # DevOps tools
    devops.kubernetes.enable = osConfig.myConfig.development.devops.enable or false;
    devops.cloud.enable = osConfig.myConfig.development.devops.enable or false;
    devops.infrastructure.enable = osConfig.myConfig.development.devops.enable or false;

    # Shell
    shell.default = lib.mkDefault (osConfig.myConfig.shell.default or defaultShell);
    shell.fish.enable = osConfig.myConfig.shell.fish.enable or false;
    shell.bash.enable = osConfig.myConfig.shell.bash.enable or false;
    shell.zsh.enable = osConfig.myConfig.shell.zsh.enable or false;
    shell.nushell.enable = osConfig.myConfig.shell.nushell.enable or false;
    shell.shared = lib.mkDefault (osConfig.myConfig.shell.shared or { });
    shell.git.enable = osConfig.myConfig.shell.git.enable or false;
    shell.ssh.enable = osConfig.myConfig.shell.ssh.enable or false;

    # Editors
    editors.neovim.enable = osConfig.myConfig.editors.neovim.enable or false;
    editors.neovim.useNightly = osConfig.myConfig.editors.neovim.useNightly or false;

    # Desktop
    desktop.hex.enable = osConfig.myConfig.darwin.hex.enable or false;
    desktop.hex.showDockIcon = false;
  };

  # Pass inputs to modules that need them
  _module.args = {
    inherit inputs;
  };
}
