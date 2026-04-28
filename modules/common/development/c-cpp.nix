{ lib, ... }:

with lib;

{
  options.myConfig.development.c = {
    enable = mkEnableOption "C/C++ development environment";
  };
}
