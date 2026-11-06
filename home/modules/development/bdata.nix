{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig.development.bdata;
  tomlFormat = pkgs.formats.toml { };
  settings = lib.recursiveUpdate (builtins.fromTOML (builtins.readFile cfg.settingsFile)) cfg.settings;
in
{
  options.myConfig.development.bdata = {
    enable = lib.mkEnableOption "bdata terminal database viewer configuration";

    settingsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../../configs/bdata/config.toml;
      description = "Base settings in bdata's config.toml format.";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = "Per-host bdata settings merged over settingsFile.";
    };
  };

  # Only config.toml: bdata writes connections.toml and snippets.toml itself.
  config = lib.mkIf cfg.enable {
    xdg.configFile."bdata/config.toml".source = tomlFormat.generate "bdata-config.toml" settings;
  };
}
