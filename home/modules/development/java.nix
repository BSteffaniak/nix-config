{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.java;
in
{
  options.myConfig.development.java = {
    enable = lib.mkEnableOption "Java development environment";

    includeKotlin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include Kotlin language server";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        maven
      ]
      ++ (lib.optional cfg.includeKotlin kotlin-language-server);
  };
}
