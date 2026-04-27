{ lib, ... }:

with lib;

{
  options.myConfig.development.java = {
    enable = mkEnableOption "Java development environment";
  };
}
