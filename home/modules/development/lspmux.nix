{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.development.lspmux;
in
{
  options.myConfig.development.lspmux = {
    enable = mkEnableOption "LSP multiplexer configuration";

    service.enable = mkOption {
      type = types.bool;
      default = cfg.enable;
      description = ''
        Auto-start lspmux server at login.
        Defaults to true when lspmux is enabled.
        On Linux, creates a systemd user service.
        On macOS, the launchd agent is managed by the darwin module.

        Restart commands:
          Linux:  systemctl --user restart lspmux
          macOS:  launchctl kickstart -k gui/$(id -u)/org.codeberg.p2502.lspmux
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Linux: ~/.config/lspmux/config.toml
      xdg.configFile."lspmux/config.toml" = mkIf pkgs.stdenv.isLinux {
        source = ../../../configs/lspmux/config.toml;
      };

      # macOS: ~/Library/Application Support/lspmux/config.toml
      home.file."Library/Application Support/lspmux/config.toml" = mkIf pkgs.stdenv.isDarwin {
        source = ../../../configs/lspmux/config.toml;
      };
    }

    # Linux: systemd user service
    (mkIf (cfg.service.enable && pkgs.stdenv.isLinux) {
      systemd.user.services.lspmux = {
        Unit = {
          Description = "LSP multiplexer server";
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.lspmux-latest}/bin/lspmux server";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    })
  ]);
}
