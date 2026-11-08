{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig.development.bclean;
  tomlFormat = pkgs.formats.toml { };
  settings = lib.recursiveUpdate (builtins.fromTOML (builtins.readFile cfg.settingsFile)) cfg.settings;
in
{
  options.myConfig.development.bclean = {
    enable = lib.mkEnableOption "bclean configuration (disk usage analyzer, cleaner, and monitor)";

    settingsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../../configs/bclean/config.toml;
      description = "Base settings in bclean's config format.";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = "Per-host bclean settings merged over settingsFile.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."bclean/config.toml".source = tomlFormat.generate "bclean-config.toml" settings;
  };
}
