{
  config,
  lib,
  options,
  ...
}:

let
  cfg = config.myConfig.shell.ssh;
in
{
  options.myConfig.shell.ssh = {
    enable = lib.mkEnableOption "SSH client configuration";

    matchBlocks = lib.mkOption {
      # Reuse home-manager's own submodule type so host blocks are validated.
      type = options.programs.ssh.matchBlocks.type;
      default = { };
      description = "SSH host configurations (see programs.ssh.matchBlocks)";
      example = lib.literalExpression ''
        {
          "github.com" = {
            user = "git";
            identityFile = "~/.ssh/id_ed25519";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
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
