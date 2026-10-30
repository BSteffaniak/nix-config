{
  config,
  lib,
  options,
  pkgs,
  hostMeta ? { },
  ...
}:

let
  cfg = config.myConfig.shell.ssh;
  fleet = cfg.fleet;
  clientKeys = lib.filter (key: key != null) (
    map (peer: peer.publicKey) (builtins.attrValues fleet.peers)
  );
  knownHosts = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: peer: "${lib.concatStringsSep "," peer.hostNames} ${peer.hostKey}") (
      lib.filterAttrs (_: peer: peer.hostKey != null) fleet.peers
    )
  );
  blocks =
    lib.optionalAttrs cfg.fleetAliases.enable (
      lib.mapAttrs (
        name: meta:
        lib.hm.dag.entryAnywhere {
          hostname = "${name}.local";
          user = meta.username;
        }
      ) hostMeta
    )
    // cfg.matchBlocks;
  fleetAliases = builtins.attrNames hostMeta ++ [
    "scar"
    "windows-desktop"
  ];
in
{
  options.myConfig.shell.ssh = {
    enable = lib.mkEnableOption "SSH client configuration";

    fleetAliases.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate local-network SSH aliases from discovered host names and usernames when the SSH client is enabled";
    };

    fleet = {
      enable = lib.mkEnableOption "locally generated dedicated fleet credentials and declarative public-key enrollment";
      peers = lib.mkOption {
        default = { };
        description = "Enrolled fleet public keys only; verify host keys out of band before adding them";
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }: {
              options = {
                publicKey = lib.mkOption {
                  type = lib.types.nullOr (lib.types.strMatching "ssh-ed25519 [A-Za-z0-9+/=]+( [^\r\n]*)?");
                  default = null;
                  description = "Client public key authorized for this account";
                };
                hostKey = lib.mkOption {
                  type = lib.types.nullOr (lib.types.strMatching "ssh-ed25519 [A-Za-z0-9+/=]+( [^\r\n]*)?");
                  default = null;
                  description = "Verified server public host key";
                };
                hostNames = lib.mkOption {
                  type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9._:-]+");
                  default = [
                    name
                    "${name}.local"
                  ];
                  description = "Aliases and addresses to pin to this server key";
                };
              };
            }
          )
        );
      };
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
    home.activation.sshFleet = lib.mkIf fleet.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.python3}/bin/python3 ${./ssh-fleet.py} \
          ${pkgs.openssh}/bin/ssh-keygen \
          ${pkgs.writeText "ssh-fleet-public-keys.json" (builtins.toJSON clientKeys)}
      ''
    );
    home.file.".ssh/fleet_known_hosts" = lib.mkIf fleet.enable {
      text = knownHosts + "\n";
    };
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks =
        lib.mapAttrs (
          name: block:
          if fleet.enable && cfg.fleetAliases.enable && builtins.elem name fleetAliases then
            block
            // {
              data = block.data // {
                identityFile =
                  if (block.data.identityFile or [ ]) == [ ] then
                    [ "~/.ssh/id_ed25519_fleet" ]
                  else
                    block.data.identityFile;
                identitiesOnly = block.data.identitiesOnly or true;
                userKnownHostsFile = "~/.ssh/fleet_known_hosts ~/.ssh/known_hosts";
                extraOptions = (block.data.extraOptions or { }) // {
                  StrictHostKeyChecking = "yes";
                };
              };
            }
          else
            block
        ) blocks
        // {
          "*" = {
            controlMaster = "auto";
            controlPersist = "10m";
          };
        };
    };
  };
}
