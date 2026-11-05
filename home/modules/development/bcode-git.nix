{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig.development.bcodeGit;
  tomlFormat = pkgs.formats.toml { };
  settings = lib.recursiveUpdate (builtins.fromTOML (builtins.readFile cfg.settingsFile)) cfg.settings;
in
{
  options.myConfig.development.bcodeGit = {
    enable = lib.mkEnableOption "Standalone Bcode Git terminal client";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bcode-git;
      description = "Standalone Bcode Git package, pinned independently of Bcode.";
    };

    settingsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../../configs/bcode-git/config.toml;
      description = "Base settings in the dedicated bcode-git config format.";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = "Per-host Bcode Git settings merged over settingsFile.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    xdg.configFile."bcode-git/config.toml".source =
      tomlFormat.generate "bcode-git-config.toml" settings;
  };
}
