{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

with lib;

let
  cfg = config.myConfig.cliTools.utilities;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;
  mkMediaEnable = myLib.mkEnableOption' cfg.media.enableAll;
in
{
  options.myConfig.cliTools.utilities = {
    enableAll = mkOption {
      type = types.bool;
      default = false;
      description = "Enable all utility tools (can be overridden per-tool)";
    };

    direnv = {
      enable = mkEnable "Direnv for per-directory environments";
      nix-direnv = mkOption {
        type = types.bool;
        default = true;
        description = "Enable nix-direnv integration";
      };
    };

    jq.enable = mkEnable "JSON processor";
    parallel.enable = mkEnable "GNU parallel";
    write-good.enable = mkEnable "writing quality checker";
    cronstrue.enable = mkEnable "cron expression diagnostic tool";
    cloc.enable = mkEnable "lines of code counter";
    watchexec.enable = mkEnable "file watcher/executor";
    lsof.enable = mkEnable "list open files utility";
    killall.enable = mkEnable "killall utility";
    nix-search.enable = mkEnable "Nix package search";

    media = {
      enableAll = mkOption {
        type = types.bool;
        default = cfg.enableAll;
        description = "Enable all media tools (can be overridden per-tool)";
      };

      ffmpeg.enable = mkMediaEnable "FFmpeg media processor";
      flac.enable = mkMediaEnable "FLAC codec";
      mediainfo.enable = mkMediaEnable "media info analyzer";
    };

    opencode.enable = mkEnable "OpenCode and Claude Code";
  };

  config = {
    # Direnv
    programs.direnv = mkIf cfg.direnv.enable {
      enable = true;
      nix-direnv.enable = cfg.direnv.nix-direnv;
    };

    # Package installs
    home.packages = mkMerge [
      (mkIf cfg.jq.enable [ pkgs.jq ])
      (mkIf cfg.parallel.enable [ pkgs.parallel ])
      (mkIf cfg.write-good.enable [ pkgs.write-good ])
      (mkIf cfg.cronstrue.enable [ pkgs.cronstrue-custom ])
      (mkIf cfg.cloc.enable [ pkgs.cloc ])
      (mkIf cfg.watchexec.enable [ pkgs.watchexec ])
      (mkIf cfg.lsof.enable [ pkgs.lsof ])
      (mkIf cfg.killall.enable [ pkgs.killall ])
      (mkIf cfg.nix-search.enable [ pkgs.nix-search ])
      (mkIf cfg.media.ffmpeg.enable [ pkgs.unstable.ffmpeg ])
      (mkIf cfg.media.flac.enable [ pkgs.flac ])
      (mkIf cfg.media.mediainfo.enable [ pkgs.mediainfo ])
      (mkIf cfg.opencode.enable [
        pkgs.unstable.opencode
      ])
    ];
  };
}
