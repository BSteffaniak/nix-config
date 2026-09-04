{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.zig;
in
{
  options.myConfig.development.zig = {
    enable = lib.mkEnableOption "Zig development environment";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ zig ];
  };
}
