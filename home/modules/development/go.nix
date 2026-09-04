{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.go;
in
{
  options.myConfig.development.go = {
    enable = lib.mkEnableOption "Go development environment";

    includeLSP = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include gopls (Go language server)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ go ] ++ (lib.optional cfg.includeLSP gopls);

    # Set up Go environment variables
    home.sessionVariables = {
      GOPATH = "$HOME/go";
      GOBIN = "$HOME/go/bin";
    };

    # Add GOBIN to PATH
    home.sessionPath = [ "$HOME/go/bin" ];
  };
}
