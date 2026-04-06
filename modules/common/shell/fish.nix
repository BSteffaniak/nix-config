{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.shell;
  fishEnabled = cfg.fish.enable || cfg.default == "fish";
in
{
  options.myConfig.shell.fish.enable = mkEnableOption "Fish shell";

  config = mkIf fishEnabled {
    # Enable fish shell at system level (required for login shells on NixOS)
    # Per-user configuration is managed by home-manager.
    programs.fish.enable = true;
  };
}
