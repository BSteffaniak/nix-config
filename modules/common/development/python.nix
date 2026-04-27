{ lib, ... }:

with lib;

{
  options.myConfig.development.python = {
    enable = mkEnableOption "Python development environment";
  };
}
