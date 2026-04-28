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

  # Dynamic configuration from host
  home.username = osConfig.myConfig.username;
  home.homeDirectory = "/home/${osConfig.myConfig.username}";

  # State version should match the NixOS release when home-manager was first used
  # Read from host config
  home.stateVersion = osConfig.system.stateVersion;

  # Mirror system configuration to home-manager modules
  # This allows the new home-manager modules to access the same settings
  myConfig = {
    # Development tools - mirror from system config
    development.rust.enable = osConfig.myConfig.development.rust.enable or false;
    development.rust.includeNightly = osConfig.myConfig.development.rust.includeNightly or false;
    development.nodejs.enable = osConfig.myConfig.development.nodejs.enable or false;
    development.go.enable = osConfig.myConfig.development.go.enable or false;
    development.python.enable = osConfig.myConfig.development.python.enable or false;
    development.android.enable = osConfig.myConfig.development.android.enable or false;
    development.java.enable = osConfig.myConfig.development.java.enable or false;
    development.elixir.enable = osConfig.myConfig.development.elixir.enable or false;
    development.zig.enable = osConfig.myConfig.development.zig.enable or false;
    development.c.enable = osConfig.myConfig.development.c.enable or false;
    development.openssl.enable = osConfig.myConfig.development.openssl.enable or false;

    # DevOps tools
    devops.kubernetes.enable = osConfig.myConfig.development.devops.enable or false;
    devops.cloud.enable = osConfig.myConfig.development.devops.enable or false;
    devops.infrastructure.enable = osConfig.myConfig.development.devops.enable or false;

    # Container tools
    containers.tools.enable = osConfig.myConfig.development.devops.enable or false;

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

    # Desktop (only configs, compositor installed at system level)
    desktop.hyprland = {
      enable = osConfig.myConfig.desktop.hyprland.enable or false;
      # Host-specific configs (set by host if needed)
      monitorsConfig = osConfig.myConfig.desktop.hyprland.monitorsConfig or null;
      workspacesConfig = osConfig.myConfig.desktop.hyprland.workspacesConfig or null;
    };
    desktop.waybar.enable = osConfig.myConfig.desktop.waybar.enable or false;
  };

  # Pass inputs to modules that need them
  _module.args = {
    inherit inputs;
  };

  # NixOS-specific home files
  home.file = {
    ".config/systemd/user/tmux.service.d/override.conf".text = ''
      [Install]

      [Service]
      ExecStart=

      [Unit]
    '';
  };
}
