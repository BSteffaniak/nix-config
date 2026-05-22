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
  brouterCfg = config.myConfig.development.brouter;
  brouterProxyCfg = config.myConfig.development.brouterProxy;
  agentPermissions = import ../../lib/agent-permissions.nix { inherit lib myLib; };
  tomlFormat = pkgs.formats.toml { };

  permissionsDir = ../../../configs/agents/permissions;
  skillsDir = ../../../configs/agents/skills;

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
    plugins.enabled = [
      "bcode.openai-compatible"
      "bcode.bedrock"
    ];

    model = {
      provider_plugin_id = "bcode.openai-compatible";
      profile = "openai";
      profiles.openai = {
        provider_plugin_id = "bcode.openai-compatible";
        model_id = cfg.providers.openai.model;
        auth_profile = cfg.authProfile;
        settings.dialect = "chatgpt_codex";
      };
      aliases."gpt-5.5-fast" = {
        provider_plugin_id = "bcode.openai-compatible";
        model_id = "gpt-5.5";
        request.service_tier = "priority";
      };
    };

    auth.profiles.${cfg.authProfile} = {
      backend = "sshenv";
      settings = {
        provider = "openai";
        profile = cfg.authProfile;
        vault = cfg.authVaultPath;
        mode = "chatgpt";
      };
    };
  };

  finalSettings = recursiveUpdate (recursiveUpdate baseSettings bcodePermissions) cfg.extraSettings;

  mkOpenAiOverlay =
    {
      model,
      authProfile ? null,
      authProvider ? "openai",
      baseUrl ? null,
      dialect ? null,
    }:
    {
      plugins.enabled = [ "bcode.openai-compatible" ];
      model = {
        provider_plugin_id = "bcode.openai-compatible";
        model_id = model;
        profile = "default";
        profiles.default = {
          provider_plugin_id = "bcode.openai-compatible";
          model_id = model;
          settings =
            optionalAttrs (baseUrl != null) {
              base_url = baseUrl;
            }
            // optionalAttrs (dialect != null) { inherit dialect; };
        }
        // optionalAttrs (authProfile != null) { auth_profile = authProfile; };
        aliases."gpt-5.5-fast" = {
          provider_plugin_id = "bcode.openai-compatible";
          model_id = "gpt-5.5";
          request.service_tier = "priority";
        };
      };
    }
    // optionalAttrs (authProfile != null) {
      auth.profiles.${authProfile} = {
        backend = "sshenv";
        settings = {
          provider = authProvider;
          profile = authProfile;
          vault = cfg.authVaultPath;
        }
        // optionalAttrs (authProvider == "openai") { mode = "chatgpt"; }
        // optionalAttrs (baseUrl != null) { base_url = baseUrl; };
      };
    };

  mkSshenvOption =
    defaultProfile: defaultValue:
    mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            profile = mkOption {
              type = types.str;
              default = defaultProfile;
              description = "sshenv profile to load before starting this Bcode provider wrapper.";
            };

            envOnly = mkOption {
              type = types.bool;
              default = true;
              description = "Load the sshenv profile as process environment variables for this provider.";
            };
          };
        }
      );
      default = defaultValue;
      description = ''
        Optional sshenv configuration for this Bcode provider wrapper.
        Bcode currently supports the Pi-style env-only mode for providers like
        Bedrock and xAI that read credentials from environment variables.
      '';
    };

  providerOverlays = {
    bedrock = {
      plugins.enabled = [ "bcode.bedrock" ];
      model = {
        provider_plugin_id = "bcode.bedrock";
        model_id = cfg.providers.bedrock.model;
        profile = "default";
        profiles.default = {
          provider_plugin_id = "bcode.bedrock";
          model_id = cfg.providers.bedrock.model;
          auth_profile = "bedrock";
          settings = optionalAttrs (cfg.providers.bedrock.region != null) {
            region = cfg.providers.bedrock.region;
          };
        };
      };
      auth.profiles.bedrock = {
        backend = "sshenv";
        settings = {
          provider = "aws";
          profile =
            if cfg.providers.bedrock.sshenv != null then cfg.providers.bedrock.sshenv.profile else "bedrock";
        }
        // optionalAttrs (cfg.providers.bedrock.awsProfile != null) {
          profile = cfg.providers.bedrock.awsProfile;
        }
        // optionalAttrs (cfg.providers.bedrock.region != null) { region = cfg.providers.bedrock.region; };
      };
    };

    openai = mkOpenAiOverlay {
      model = cfg.providers.openai.model;
      authProfile = cfg.providers.openai.authProfile;
      authProvider = "openai";
      dialect = "chatgpt_codex";
    };

    codex = mkOpenAiOverlay {
      model = cfg.providers.codex.model;
      authProfile = cfg.providers.codex.authProfile;
      authProvider = "openai";
      dialect = "chatgpt_codex";
    };

    brouter = mkOpenAiOverlay {
      model = cfg.providers.brouter.model;
      baseUrl = "http://${brouterCfg.host}:${toString brouterCfg.port}/v1";
    };

    xai = mkOpenAiOverlay {
      model = cfg.providers.xai.model;
      authProfile = "xai";
      authProvider = "xai";
      baseUrl = "https://api.x.ai/v1";
    };

    grok-4-3 = mkOpenAiOverlay {
      model = cfg.providers.xai.model;
      authProfile = "xai";
      authProvider = "xai";
      baseUrl = "https://api.x.ai/v1";
    };

    grok-code-fast = mkOpenAiOverlay {
      model = cfg.providers.xai.codeFastModel;
      authProfile = "xai";
      authProvider = "xai";
      baseUrl = "https://api.x.ai/v1";
    };

    brouter-proxy = mkOpenAiOverlay {
      model = cfg.providers.brouterProxy.model;
      baseUrl = "http://${brouterProxyCfg.host}:${toString brouterProxyCfg.port}/v1";
    };
  }
  // cfg.extraProviderOverlays;

  providerSshenv = filterAttrs (_name: spec: spec != null) (
    {
      bedrock = cfg.providers.bedrock.sshenv;
      openai = cfg.providers.openai.sshenv;
      codex = cfg.providers.codex.sshenv;
      xai = cfg.providers.xai.sshenv;
      "grok-4-3" = cfg.providers.xai.sshenv;
      "grok-code-fast" = cfg.providers.xai.sshenv;
      brouter = cfg.providers.brouter.sshenv;
      "brouter-proxy" = cfg.providers.brouterProxy.sshenv;
    }
    // cfg.extraProviderSshenv
  );

  providerNames = builtins.attrNames providerOverlays;

  mkProviderWrapper =
    name:
    let
      sshenvSpec = providerSshenv.${name} or null;
      command = ''env BCODE_CONFIG="$HOME/.config/bcode/providers/${name}.toml" bcode "$@"'';
    in
    if sshenvSpec != null then
      ''
        exec ${pkgs.sshenv}/bin/sshenv run ${escapeShellArg sshenvSpec.profile} -- ${command}
      ''
    else
      ''
        exec ${command}
      '';

  providerWrapperCommands = builtins.listToAttrs (
    map (name: {
      name = "bcode-${name}";
      value = mkProviderWrapper name;
    }) providerNames
  );
in
{
  options.myConfig.development.bcode = {
    enable = mkEnableOption "Bcode coding agent configuration";

    package = mkOption {
      type = types.nullOr types.package;
      default = pkgs.bcode or null;
      description = "Optional Bcode package to install. Set to null when Bcode is installed outside this Nix configuration.";
    };

    authProfile = mkOption {
      type = types.str;
      default = "openai";
      description = "Shared sshenv profile used for default Bcode OpenAI/ChatGPT authentication.";
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

    extraProviderOverlays = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Additional Bcode provider overlay TOML settings, keyed by wrapper/provider name.";
    };

    extraProviderSshenv = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            profile = mkOption {
              type = types.str;
              description = "sshenv profile to load before starting this extra Bcode provider wrapper.";
            };

            envOnly = mkOption {
              type = types.bool;
              default = true;
              description = "Load the sshenv profile as process environment variables for this provider.";
            };
          };
        }
      );
      default = { };
      description = "Additional sshenv wrapper settings, keyed by extra provider/wrapper name.";
    };

    providers = {
      bedrock = {
        model = mkOption {
          type = types.str;
          default = "global.anthropic.claude-opus-4-7";
          description = "Bedrock model used by bcode-bedrock.";
        };

        region = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional AWS region setting for bcode-bedrock.";
        };

        awsProfile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional AWS profile setting for bcode-bedrock.";
        };

        sshenv = mkSshenvOption "bedrock" {
          profile = "bedrock";
          envOnly = true;
        };
      };

      openai = {
        model = mkOption {
          type = types.str;
          default = "gpt-5.5-fast";
          description = "OpenAI/ChatGPT model used by bcode-openai.";
        };

        authProfile = mkOption {
          type = types.str;
          default = "openai";
          description = "Shared sshenv profile used by bcode-openai.";
        };

        sshenv = mkSshenvOption "openai" null;
      };

      codex = {
        model = mkOption {
          type = types.str;
          default = "gpt-5.3-codex";
          description = "Codex model used by bcode-codex.";
        };

        authProfile = mkOption {
          type = types.str;
          default = "openai";
          description = "Shared sshenv profile used by bcode-codex.";
        };

        sshenv = mkSshenvOption "openai" null;
      };

      xai = {
        model = mkOption {
          type = types.str;
          default = "grok-4.3";
          description = "xAI/Grok model used by bcode-xai.";
        };

        codeFastModel = mkOption {
          type = types.str;
          default = "grok-code-fast";
          description = "xAI/Grok Code Fast model used by bcode-grok-code-fast.";
        };

        sshenv = mkSshenvOption "xai" {
          profile = "xai";
          envOnly = true;
        };
      };

      brouter = {
        model = mkOption {
          type = types.str;
          default = brouterCfg.defaultModel;
          description = "Model used by bcode-brouter against the local brouter OpenAI-compatible endpoint.";
        };

        sshenv = mkSshenvOption "brouter" null;
      };

      brouterProxy = {
        model = mkOption {
          type = types.str;
          default = brouterProxyCfg.defaultModel;
          description = "Model used by bcode-brouter-proxy against the local brouter-proxy OpenAI-compatible endpoint.";
        };

        sshenv = mkSshenvOption "brouter-proxy" null;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = mapAttrsToList (name: spec: {
        assertion = spec.envOnly;
        message = "Bcode provider '${name}' only supports sshenv.envOnly = true.";
      }) providerSshenv;

      home.packages = optional (cfg.package != null) cfg.package;

      xdg.configFile."bcode/bcode.toml".source = tomlFormat.generate "bcode.toml" finalSettings;
      xdg.configFile."bcode/skills".source = skillsDir;

      homeModules.shell.shared.functions = providerWrapperCommands;
    }
    {
      xdg.configFile = mapAttrs' (name: overlay: {
        name = "bcode/providers/${name}.toml";
        value.source = tomlFormat.generate "bcode-provider-${name}.toml" overlay;
      }) providerOverlays;
    }
  ]);
}
