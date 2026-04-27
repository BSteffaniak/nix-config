{ lib, ... }:

with lib;

{
  options.myConfig.development.zig = {
    enable = mkEnableOption "Zig development environment";
  };
}
