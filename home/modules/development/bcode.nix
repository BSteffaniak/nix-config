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
        accent = "#22d3ee";
        tools = {
          "filesystem.read" = true;
          "filesystem.write" = true;
          "filesystem.edit" = true;
          "shell.run" = true;
          "web.search" = true;
          "web.fetch" = true;
          "web.status" = true;
          "web.inspect" = true;
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
          web = {
            "*" = "allow";
          };
          external_directory = "allow";
        };
      };

      plan = {
        accent = "#6b7280";
        tools = {
          "filesystem.read" = true;
          "filesystem.write" = false;
          "filesystem.edit" = false;
          "shell.run" = true;
          "web.search" = true;
          "web.fetch" = true;
          "web.status" = true;
          "web.inspect" = true;
        };
        permission = {
          bash = {
            "*" = "deny";
          };
          web = {
            "*" = "allow";
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
    grep = "filesystem.grep";
    find = "filesystem.find";
    ls = "filesystem.list";
    stat = "filesystem.stat";
    write = "filesystem.write";
    edit = "filesystem.edit";
    "worktree.read" = "worktree.list";
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

    tui.keybindings.chat = {
      enter = "tui.input.newLine";
      "ctrl+enter" = "tui.input.submitSteering";
      "ctrl+shift+enter" = "tui.input.submitFollowUp";
    };

    model.metadata."gpt-5.5".reasoning.default_effort = "none";

    # Keep plain `bcode` credential-free. Provider-specific wrappers such as
    # `bcode-openai` and host-private profile wrappers point BCODE_CONFIG at
    # generated provider configs that contain their own scoped auth profiles.
    model.aliases."gpt-5.5-fast" = {
      provider_plugin_id = "bcode.openai-compatible";
      model_id = "gpt-5.5";
      request.service_tier = "priority";
    };
  };

  finalSettings = recursiveUpdate (recursiveUpdate baseSettings bcodePermissions) cfg.extraSettings;

  openAiFastAlias = {
    "gpt-5.5-fast" = {
      provider_plugin_id = "bcode.openai-compatible";
      model_id = "gpt-5.5";
      request.service_tier = "priority";
    };
  };

  mkProfileOverlay =
    name: profile:
    let
      authProfile = profile.authProfile or null;
      authConfig = profile.auth or null;
      settings = profile.settings or { };
      aliases = profile.aliases or { };
      plugins = profile.plugins or [ profile.providerPluginId ];
      baseOverlay = {
        plugins.enabled = plugins;
        model = {
          provider_plugin_id = profile.providerPluginId;
          model_id = profile.model;
          profile = "default";
          profiles.default = {
            provider_plugin_id = profile.providerPluginId;
            model_id = profile.model;
            inherit settings;
          }
          // optionalAttrs (authProfile != null) { auth_profile = authProfile; };
          inherit aliases;
        };
      }
      // optionalAttrs (authProfile != null && authConfig != null) {
        auth.profiles.${authProfile} = authConfig;
      };
    in
    recursiveUpdate baseOverlay (profile.extraConfig or { });

  profileWithoutVariants = profile: removeAttrs profile [ "variants" ];

  mergeProfileVariant = profile: variant: recursiveUpdate (profileWithoutVariants profile) variant;

  expandProfileOverlays =
    name: profile:
    let
      baseProfile = profileWithoutVariants profile;
      variants = profile.variants or { };
    in
    {
      ${name} = mkProfileOverlay name baseProfile;
    }
    // mapAttrs' (variantName: variant: {
      name = "${name}-${variantName}";
      value = mkProfileOverlay "${name}-${variantName}" (mergeProfileVariant profile variant);
    }) variants;

  mkProfileOverlays =
    profiles:
    foldl' (acc: name: acc // expandProfileOverlays name profiles.${name}) { } (attrNames profiles);

  expandProfileSshenv =
    name: profile:
    let
      baseProfile = profileWithoutVariants profile;
      variants = profile.variants or { };
      base = optionalAttrs (baseProfile ? sshenv && baseProfile.sshenv != null) {
        ${name} = baseProfile.sshenv;
      };
    in
    base
    // concatMapAttrs (
      variantName: variant:
      let
        merged = mergeProfileVariant profile variant;
      in
      optionalAttrs (merged ? sshenv && merged.sshenv != null) {
        "${name}-${variantName}" = merged.sshenv;
      }
    ) variants;

  mkProfileSshenv =
    profiles:
    foldl' (acc: name: acc // expandProfileSshenv name profiles.${name}) { } (attrNames profiles);

  mkOpenAiProfile =
    {
      model,
      authProfile,
      fastModel ? null,
      authProvider ? "openai",
      baseUrl ? null,
      dialect ? null,
      variants ? { },
    }:
    {
      providerPluginId = "bcode.openai-compatible";
      inherit model authProfile;
      settings =
        optionalAttrs (baseUrl != null) { base_url = baseUrl; }
        // optionalAttrs (dialect != null) { inherit dialect; };
      aliases = openAiFastAlias;
      auth = {
        backend = "sshenv";
        settings = {
          provider = authProvider;
          profile = authProfile;
          vault = cfg.authVaultPath;
        }
        // optionalAttrs (authProvider == "openai") { mode = "chatgpt"; }
        // optionalAttrs (baseUrl != null) { base_url = baseUrl; };
      };
      variants =
        variants
        // optionalAttrs (fastModel != null) {
          fast.model = fastModel;
        };
    };

  mkOpenAiCompatibleApiProfile =
    {
      model,
      authProfile,
      authProvider,
      baseUrl,
      apiKeyEnv,
      authVaultPath ? cfg.authVaultPath,
      dialect ? "chat_completions",
      aliases ? { },
      variants ? { },
      sshenv ? null,
    }:
    {
      providerPluginId = "bcode.openai-compatible";
      inherit
        model
        authProfile
        aliases
        variants
        ;
      settings = {
        base_url = baseUrl;
        api_key_env = apiKeyEnv;
        inherit dialect;
      };
      auth = {
        backend = "sshenv";
        scheme = "api_key";
        map.api_key.env = apiKeyEnv;
        settings = {
          provider = authProvider;
          profile = authProfile;
          vault = authVaultPath;
          mode = "api_key";
          api_key_env = apiKeyEnv;
          base_url = baseUrl;
        };
      };
    }
    // optionalAttrs (sshenv != null) { inherit sshenv; };

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

  builtinProfiles = {
    bedrock = {
      providerPluginId = "bcode.bedrock";
      model = cfg.providers.bedrock.model;
      authProfile = "bedrock";
      settings = optionalAttrs (cfg.providers.bedrock.region != null) {
        region = cfg.providers.bedrock.region;
      };
      auth = {
        backend = "sshenv";
        scheme = "aws_credentials";
        map = {
          access_key_id.env = "AWS_ACCESS_KEY_ID";
          secret_access_key.env = "AWS_SECRET_ACCESS_KEY";
          session_token.env = "AWS_SESSION_TOKEN";
          bearer_token.env = "AWS_BEARER_TOKEN_BEDROCK";
        };
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
      sshenv = cfg.providers.bedrock.sshenv;
    };

    openai = mkOpenAiProfile {
      model = cfg.providers.openai.model;
      fastModel = cfg.providers.openai.fastModel;
      authProfile = cfg.providers.openai.authProfile;
      authProvider = "openai";
      dialect = "chatgpt_codex";
    };

    codex = mkOpenAiProfile {
      model = cfg.providers.codex.model;
      authProfile = cfg.providers.codex.authProfile;
      authProvider = "openai";
      dialect = "chatgpt_codex";
    };

    brouter = {
      providerPluginId = "bcode.openai-compatible";
      model = cfg.providers.brouter.model;
      settings.base_url = "http://${brouterCfg.host}:${toString brouterCfg.port}/v1";
      aliases = openAiFastAlias;
      sshenv = cfg.providers.brouter.sshenv;
    };

    openrouter = mkOpenAiCompatibleApiProfile {
      model = cfg.providers.openrouter.model;
      authProfile = cfg.providers.openrouter.authProfile;
      authProvider = "openrouter";
      baseUrl = cfg.providers.openrouter.baseUrl;
      apiKeyEnv = cfg.providers.openrouter.apiKeyEnv;
      authVaultPath = cfg.providers.openrouter.authVaultPath;
      sshenv = cfg.providers.openrouter.sshenv;
    };

    zen = mkOpenAiCompatibleApiProfile {
      model = cfg.providers.zen.model;
      authProfile = cfg.providers.zen.authProfile;
      authProvider = "opencode";
      baseUrl = cfg.providers.zen.baseUrl;
      apiKeyEnv = cfg.providers.zen.apiKeyEnv;
      authVaultPath = cfg.providers.zen.authVaultPath;
      sshenv = cfg.providers.zen.sshenv;
    };

    xai =
      mkOpenAiProfile {
        model = cfg.providers.xai.model;
        authProfile = "xai";
        authProvider = "xai";
        baseUrl = "https://api.x.ai/v1";
      }
      // {
        sshenv = cfg.providers.xai.sshenv;
      };

    grok-4-3 =
      mkOpenAiProfile {
        model = cfg.providers.xai.model;
        authProfile = "xai";
        authProvider = "xai";
        baseUrl = "https://api.x.ai/v1";
      }
      // {
        sshenv = cfg.providers.xai.sshenv;
      };

    grok-code-fast =
      mkOpenAiProfile {
        model = cfg.providers.xai.codeFastModel;
        authProfile = "xai";
        authProvider = "xai";
        baseUrl = "https://api.x.ai/v1";
      }
      // {
        sshenv = cfg.providers.xai.sshenv;
      };

    brouter-proxy = {
      providerPluginId = "bcode.openai-compatible";
      model = cfg.providers.brouterProxy.model;
      settings.base_url = "http://${brouterProxyCfg.host}:${toString brouterProxyCfg.port}/v1";
      aliases = openAiFastAlias;
      sshenv = cfg.providers.brouterProxy.sshenv;
    };
  };

  allProfiles = builtinProfiles // cfg.profiles;

  providerOverlays = mkProfileOverlays allProfiles // cfg.extraProviderOverlays;

  providerSshenv = filterAttrs (_name: spec: spec != null) (
    mkProfileSshenv allProfiles // cfg.extraProviderSshenv
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

    profiles = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = ''
        Generic generated Bcode provider profiles, keyed by wrapper name without the `bcode-` prefix.

        Each profile supports fields like `providerPluginId`, `model`, `authProfile`, `auth`,
        `settings`, `aliases`, `variants`, `plugins`, `sshenv`, and `extraConfig`. Variants are
        generated as `bcode-<name>-<variant>` wrappers. This is the preferred extension point for
        host-private provider/account profiles because names and auth profile IDs stay in the host
        file that defines them.
      '';
    };

    extraProviderOverlays = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Raw Bcode provider overlay TOML settings, keyed by wrapper/provider name. Prefer `profiles` for generated provider configs.";
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
          default = "global.anthropic.claude-opus-4-8";
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
          default = "gpt-5.5";
          description = "OpenAI/ChatGPT model used by bcode-openai.";
        };

        fastModel = mkOption {
          type = types.str;
          default = "gpt-5.5-fast";
          description = "Priority-tier OpenAI/ChatGPT model alias used by bcode-openai-fast.";
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

      openrouter = {
        model = mkOption {
          type = types.str;
          default = "z-ai/glm-5.1";
          description = "OpenRouter model used by bcode-openrouter.";
        };

        baseUrl = mkOption {
          type = types.str;
          default = "https://openrouter.ai/api/v1";
          description = "OpenRouter OpenAI-compatible API base URL.";
        };

        authProfile = mkOption {
          type = types.str;
          default = "openrouter";
          description = "sshenv auth profile used by bcode-openrouter.";
        };

        authVaultPath = mkOption {
          type = types.str;
          default = cfg.authVaultPath;
          description = "sshenv vault path used by bcode-openrouter.";
        };

        apiKeyEnv = mkOption {
          type = types.str;
          default = "OPENROUTER_API_KEY";
          description = "API key environment variable loaded from the bcode-openrouter sshenv profile.";
        };

        sshenv = mkSshenvOption "openrouter" {
          profile = "openrouter";
          envOnly = true;
        };
      };

      zen = {
        model = mkOption {
          type = types.str;
          default = "big-pickle";
          description = "OpenCode Zen model used by bcode-zen.";
        };

        baseUrl = mkOption {
          type = types.str;
          default = "https://opencode.ai/zen/v1";
          description = "OpenCode Zen OpenAI-compatible API base URL.";
        };

        authProfile = mkOption {
          type = types.str;
          default = "opencode-zen";
          description = "sshenv auth profile used by bcode-zen.";
        };

        authVaultPath = mkOption {
          type = types.str;
          default = cfg.authVaultPath;
          description = "sshenv vault path used by bcode-zen.";
        };

        apiKeyEnv = mkOption {
          type = types.str;
          default = "OPENCODE_API_KEY";
          description = "API key environment variable loaded from the bcode-zen sshenv profile.";
        };

        sshenv = mkSshenvOption "opencode-zen" {
          profile = "opencode-zen";
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
