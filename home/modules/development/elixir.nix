{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.elixir;
in
{
  options.myConfig.development.elixir = {
    enable = lib.mkEnableOption "Elixir development environment";

    includeLSP = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include Elixir language server";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        elixir
      ]
      ++ (lib.optional cfg.includeLSP beamMinimal27Packages.elixir-ls);
  };
}
