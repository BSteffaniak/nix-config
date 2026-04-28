{ lib, ... }:

with lib;

{
  options.myConfig.development.elixir = {
    enable = mkEnableOption "Elixir development environment";
  };
}
