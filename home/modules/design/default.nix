{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.design;
in
{
  options.myConfig.design = {
    figma.enable = lib.mkEnableOption "Figma design tool";
  };

  config = {
    home.packages = lib.mkIf (cfg.figma.enable && pkgs.stdenv.isLinux) [
      pkgs.figma-linux
    ];
  };
}
