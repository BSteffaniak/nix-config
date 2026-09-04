# NixOS -> home-manager bridge.
#
# User-facing feature flags are declared directly in the host's home.nix.
# Only genuinely system-owned settings are mirrored from the OS config here.
{
  lib,
  osConfig,
  ...
}:

{
  imports = [ ../common ];

  myConfig = {
    # Login shells are declared at system level so they can be used as login
    # shells; mirror them so home-manager configures the same set.
    shell = {
      default = lib.mkDefault osConfig.myConfig.shell.default;
      fish.enable = lib.mkDefault osConfig.myConfig.shell.fish.enable;
      bash.enable = lib.mkDefault osConfig.myConfig.shell.bash.enable;
      zsh.enable = lib.mkDefault osConfig.myConfig.shell.zsh.enable;
      nushell.enable = lib.mkDefault osConfig.myConfig.shell.nushell.enable;
    };

    # The compositor is installed at system level; home-manager only manages
    # its config files.
    desktop.hyprland = {
      enable = lib.mkDefault osConfig.myConfig.desktop.hyprland.enable;
      monitorsConfig = lib.mkDefault osConfig.myConfig.desktop.hyprland.monitorsConfig;
      workspacesConfig = lib.mkDefault osConfig.myConfig.desktop.hyprland.workspacesConfig;
    };
    desktop.waybar.enable = lib.mkDefault osConfig.myConfig.desktop.waybar.enable;
  };
}
