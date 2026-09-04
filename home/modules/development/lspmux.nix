{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.lspmux;
in
{
  options.myConfig.development.lspmux = {
    enable = lib.mkEnableOption "LSP multiplexer configuration";

    service.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = ''
        Auto-start lspmux server at login.
        Defaults to true when lspmux is enabled.
        On Linux, creates a systemd user service.
        On macOS, creates a launchd user agent.

        Restart commands:
          Linux:  systemctl --user restart lspmux
          macOS:  launchctl kickstart -k gui/$(id -u)/org.codeberg.p2502.lspmux
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Linux: ~/.config/lspmux/config.toml
        xdg.configFile."lspmux/config.toml" = lib.mkIf pkgs.stdenv.isLinux {
          source = ../../../configs/lspmux/config.toml;
        };

        # macOS: ~/Library/Application Support/lspmux/config.toml
        home.file."Library/Application Support/lspmux/config.toml" = lib.mkIf pkgs.stdenv.isDarwin {
          source = ../../../configs/lspmux/config.toml;
        };
      }

      # Linux: systemd user service
      (lib.mkIf (cfg.service.enable && pkgs.stdenv.isLinux) {
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

      # macOS: launchd user agent
      (lib.mkIf (cfg.service.enable && pkgs.stdenv.isDarwin) {
        launchd.agents.lspmux = {
          enable = true;
          config = {
            Label = "org.codeberg.p2502.lspmux";
            ProgramArguments = [
              "${pkgs.lspmux-latest}/bin/lspmux"
              "server"
            ];
            RunAtLoad = true;
            KeepAlive = true;
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/lspmux.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/lspmux.err.log";
          };
        };
      })
    ]
  );
}
