{ lib, ... }:

with lib;

{
  options.myConfig.development.nodejs = {
    enable = mkEnableOption "Node.js development environment";
  };
}
