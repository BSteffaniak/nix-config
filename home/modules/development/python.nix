{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.python;
in
{
  options.myConfig.development.python = {
    enable = lib.mkEnableOption "Python development environment";

    includeTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include black, isort, and pyright";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        python3
      ]
      ++ (lib.optionals cfg.includeTools [
        black # Python code formatter
        isort # Python import sorter
        pyright # Python type checker/LSP
      ]);

    # Python user site packages
    home.sessionVariables = {
      PYTHONUSERBASE = "$HOME/.local";
    };
  };
}
