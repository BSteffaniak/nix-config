{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.shell.ssh;
in
{
  options.myConfig.shell.ssh = {
    enable = mkEnableOption "SSH client configuration";

    matchBlocks = mkOption {
      type = types.attrs;
      default = { };
      description = "SSH host configurations";
      example = literalExpression ''
        {
          "github.com" = {
            user = "git";
            identityFile = "~/.ssh/id_ed25519";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = cfg.matchBlocks // {
        "*" = {
          controlMaster = "auto";
          controlPersist = "10m";
        };
      };
    };
  };
}
