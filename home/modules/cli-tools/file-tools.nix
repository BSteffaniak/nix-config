{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

let
  cfg = config.myConfig.cliTools.fileTools;

  mkEnable = myLib.mkEnableOption' cfg.enableAll;
in
{
  options.myConfig.cliTools.fileTools = {
    enableAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable all file tools (can be overridden per-tool)";
    };

    fzf.enable = mkEnable "Fuzzy finder";
    ripgrep.enable = mkEnable "Ripgrep search tool";
    fd.enable = mkEnable "Fd file finder";
    unzip.enable = mkEnable "Unzip utility";
    zip.enable = mkEnable "Zip utility";
  };

  config = {
    home.packages = lib.mkMerge [
      (lib.mkIf cfg.fzf.enable [ pkgs.fzf ])
      (lib.mkIf cfg.ripgrep.enable [ pkgs.ripgrep ])
      (lib.mkIf cfg.fd.enable [ pkgs.fd ])
      (lib.mkIf cfg.unzip.enable [ pkgs.unzip ])
      (lib.mkIf cfg.zip.enable [ pkgs.zip ])
    ];
  };
}
