{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.devops.github;
in
{
  options.myConfig.devops.github = {
    enable = mkEnableOption "GitHub CLI and tools configuration";
  };

  config = mkIf cfg.enable {
    # Install gh package (don't use programs.gh to avoid conflicts)
    home.packages = with pkgs; [ gh ];

    # Manually symlink standalone GitHub CLI configs from configs/gh
    # NOTE: hosts.yml is NOT managed here - let gh auth login handle it
    xdg.configFile = {
      "gh/config.yml".source = ../../../configs/gh/config.yml;
      "gh-dash/config.yml".source = ../../../configs/gh/gh-dash/config.yml;
    };
  };
}
