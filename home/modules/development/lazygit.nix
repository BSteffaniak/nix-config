{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.lazygit;
in
{
  options.myConfig.development.lazygit = {
    enable = lib.mkEnableOption "LazyGit TUI configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.lazygit = {
      enable = true;
      package = pkgs.unstable.lazygit;
    };

    # Symlink standalone lazygit config from configs/lazygit
    # macOS uses ~/Library/Application Support, Linux uses ~/.config
    home.file = lib.mkIf pkgs.stdenv.isDarwin {
      "Library/Application Support/lazygit/config.yml".source = ../../../configs/lazygit/config.yml;
    };

    xdg.configFile = lib.mkIf (!pkgs.stdenv.isDarwin) {
      "lazygit/config.yml".source = ../../../configs/lazygit/config.yml;
    };
  };
}
