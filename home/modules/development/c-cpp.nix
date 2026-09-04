{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.c;
in
{
  options.myConfig.development.c = {
    enable = lib.mkEnableOption "C/C++ development environment";

    includeLSP = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include clangd language server";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        gcc
        clang
      ]
      ++ (lib.optional cfg.includeLSP clang-tools);
  };
}
