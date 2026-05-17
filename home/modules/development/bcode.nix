{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:

with lib;

let
  cfg = config.myConfig.development.bcode;
  agentsCfg = config.myConfig.development.agents;
  agentPermissions = import ../../lib/agent-permissions.nix { inherit lib myLib; };
  tomlFormat = pkgs.formats.toml { };

  permissionsDir = ../../../configs/agents/permissions;

  bcodeBasePermissionConfig = {
    agent = {
      build = {
        tools = {
          "filesystem.read" = true;
          "filesystem.write" = true;
          "filesystem.edit" = true;
          "shell.run" = true;
        };
        permission = {
          bash = {
            "*" = "allow";
          };
          write = {
            "**" = "allow";
          };
          edit = {
            "**" = "allow";
          };
          external_directory = "allow";
        };
      };

      plan = {
        tools = {
          "filesystem.read" = true;
          "filesystem.write" = false;
          "filesystem.edit" = false;
          "shell.run" = true;
        };
        permission = {
          bash = {
            "*" = "deny";
          };
          external_directory = "allow";
        };
      };
    };
  };

  mergedPermissions = agentPermissions.mkPermissions {
    inherit permissionsDir;
    cfg = agentsCfg.permissions;
    basePermissionConfig = bcodeBasePermissionConfig;
    overrides = agentsCfg.permissions.overrides ++ cfg.permissionOverrides;
  };

  toolAliases = {
    bash = "shell.run";
    read = "filesystem.read";
    write = "filesystem.write";
    edit = "filesystem.edit";
  };

  normalizeTools =
    tools:
    builtins.listToAttrs (
      mapAttrsToList (name: enabled: {
        name = toolAliases.${name} or name;
        value = enabled;
      }) tools
    );

  normalizeAgent =
    agentConfig:
    agentConfig
    // optionalAttrs (agentConfig ? tools) {
      tools = normalizeTools agentConfig.tools;
    };

  bcodePermissions = mergedPermissions // {
    agent = mapAttrs (_name: normalizeAgent) (mergedPermissions.agent or { });
  };

  baseSettings = {
    plugins.enabled = [ "bcode.openai-compatible" ];

    model.provider_plugin_id = "bcode.openai-compatible";

    auth.openai = {
      backend = "sshenv";
      mode = "chatgpt";
      profile = cfg.authProfile;
      vault = cfg.authVaultPath;
    };
  };

  finalSettings = recursiveUpdate (recursiveUpdate baseSettings bcodePermissions) cfg.extraSettings;
in
{
  options.myConfig.development.bcode = {
    enable = mkEnableOption "Bcode coding agent configuration";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "Optional Bcode package to install. Set to null when Bcode is installed outside this Nix configuration.";
    };

    authProfile = mkOption {
      type = types.str;
      default = "bcode-openai";
      description = "sshenv profile used for Bcode OpenAI/ChatGPT authentication.";
    };

    authVaultPath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.local/state/bcode/auth/vault";
      description = "sshenv vault path used for Bcode OpenAI/ChatGPT authentication.";
    };

    permissionOverrides = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Bcode-specific agent permission JSON files merged after shared permission files.";
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional Bcode TOML settings merged after generated shared agent permissions.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = optional (cfg.package != null) cfg.package;

    xdg.configFile."bcode/bcode.toml".source = tomlFormat.generate "bcode.toml" finalSettings;
  };
}
