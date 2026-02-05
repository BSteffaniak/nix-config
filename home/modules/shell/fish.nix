# This integrates the existing home/modules/fish.nix with myConfig options
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.shell.fish;
in
{
  options.myConfig.shell.fish = {
    enable = mkEnableOption "Fish shell configuration";

    # Import the existing detailed fish configuration
    extraConfigFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional fish config files to source";
    };
  };

  config = mkIf cfg.enable {
    # Enable the existing homeModules.fish configuration
    homeModules.fish = {
      enable = true;
      extraConfigFiles = cfg.extraConfigFiles;

      # Enable sensible defaults
      direnv.enable = true;
      editor.enable = true;
      utilities.enable = true;

      # Enable opencode alias if opencode development tools are enabled
      opencode.enable = config.myConfig.development.opencode.enable or false;
    };

    # Install fish plugins
    home.packages = with pkgs; [
      fishPlugins.bass
      fishPlugins.done
    ];
  };
}
