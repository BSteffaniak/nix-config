# nix-darwin -> home-manager bridge.
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

    # Hex is installed as a Homebrew cask; home-manager manages its prefs.
    desktop.hex.enable = lib.mkDefault osConfig.myConfig.darwin.hex.enable;
    desktop.hex.showDockIcon = lib.mkDefault false;

    # Ghostty is installed as a Homebrew cask on Darwin, but still use Nix to
    # provide terminfo for ncurses apps such as htop.
    cliTools.terminals.ghostty.installTerminfo = lib.mkDefault osConfig.myConfig.darwin.ghostty.enable;
  };
}
