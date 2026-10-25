{
  config,
  lib,
  options,
  hostMeta ? { },
  ...
}:

let
  cfg = config.myConfig.shell.ssh;
in
{
  options.myConfig.shell.ssh = {
    enable = lib.mkEnableOption "SSH client configuration";

    fleetAliases.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate local-network SSH aliases from discovered host names and usernames when the SSH client is enabled";
    };

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
      matchBlocks =
        lib.optionalAttrs cfg.fleetAliases.enable (
          lib.mapAttrs (name: meta: {
            hostname = "${name}.local";
            user = meta.username;
          }) hostMeta
        )
        // cfg.matchBlocks
        // {
          "*" = {
            controlMaster = "auto";
            controlPersist = "10m";
          };
        };
    };
  };
}
