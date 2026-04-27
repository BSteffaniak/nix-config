{ lib, ... }:

with lib;

{
  options.myConfig.development.go = {
    enable = mkEnableOption "Go development environment";
  };
}
