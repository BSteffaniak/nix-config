{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.lspmux;
in
{
  options.myConfig.darwin.lspmux = {
    service.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Auto-start lspmux server at login via launchd.
        Enabled by default; set to false to opt out.

        Restart: launchctl kickstart -k gui/$(id -u)/org.codeberg.p2502.lspmux
        Status:  launchctl print gui/$(id -u)/org.codeberg.p2502.lspmux
        Logs:    tail -f ~/Library/Logs/lspmux.log
      '';
    };
  };

  config = mkIf cfg.service.enable {
    launchd.user.agents.lspmux = {
      serviceConfig = {
        Label = "org.codeberg.p2502.lspmux";
        ProgramArguments = [
          "${pkgs.lspmux-latest}/bin/lspmux"
          "server"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/Users/${config.myConfig.username}/Library/Logs/lspmux.log";
        StandardErrorPath = "/Users/${config.myConfig.username}/Library/Logs/lspmux.err.log";
      };
    };
  };
}
