{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.design;
in
{
  options.myConfig.design = {
    figma.enable = mkEnableOption "Figma design tool";
  };

  config = {
    home.packages = mkIf (cfg.figma.enable && pkgs.stdenv.isLinux) [
      pkgs.figma-linux
    ];
  };
}
