{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.bcode;
  agentsCfg = config.myConfig.development.agents;
  brouterCfg = config.myConfig.development.brouter;
  brouterProxyCfg = config.myConfig.development.brouterProxy;
  agentPermissions = import ../../lib/agent-permissions.nix { inherit lib; };
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
          "vim_edit.preview" = true;
          "vim_edit.apply" = true;
          "shell.run" = true;
          "web.search" = true;
          "web.fetch" = true;
          "web.status" = true;
          "web.inspect" = true;
        };
        permission = {
          command = {
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
          "vim_edit.preview" = true;
          "vim_edit.apply" = false;
          "shell.run" = true;
          "web.search" = true;
          "web.fetch" = true;
          "web.status" = true;
          "web.inspect" = true;
        };
        permission = {
          command = {
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

  bcodePermissions = mergedPermissions;

  renameBcodePermissionCategory =
    permissions:
    if permissions ? bash then
      let
        withoutBash = removeAttrs permissions [ "bash" ];
        commandRules =
          if permissions ? command then
            lib.recursiveUpdate permissions.command permissions.bash
          else
            permissions.bash;
      in
      withoutBash // { command = commandRules; }
    else
      permissions;

  renameBcodeToolKey =
    tools:
    if tools ? bash then (removeAttrs tools [ "bash" ]) // { "shell.run" = tools.bash; } else tools;

  normalizeBcodeAgent =
    agent:
    agent
    // lib.optionalAttrs (agent ? permission && builtins.isAttrs agent.permission) {
      permission = renameBcodePermissionCategory agent.permission;
    }
    // lib.optionalAttrs (agent ? tools && builtins.isAttrs agent.tools) {
      tools = renameBcodeToolKey agent.tools;
    };

  normalizeBcodeAgentConfig =
    settings:
    settings
    // lib.optionalAttrs (settings ? agent && builtins.isAttrs settings.agent) {
      agent = lib.mapAttrs (_name: agent: normalizeBcodeAgent agent) settings.agent;
    };

  longContextCompaction = providerPluginId: threshold: {
    provider_plugin_id = providerPluginId;
    mode = "proactive_and_overflow";
    proactive_threshold_tokens = threshold;
  };

  openAiPricingBarrierModels = [
    "gpt-5.4"
    "gpt-5.4-pro"
    "gpt-5.5"
  ];

  openAiLongContextModels = [
    "gpt-6-astra"
    "gpt-6-sol"
    "gpt-6-luna"
    "gpt-5.6-sol"
    "gpt-5.6-terra"
    "gpt-5.6-luna"
    "gpt-5.6-cyber"
  ];

  pricingBarrierCompactionModels =
    lib.genAttrs openAiLongContextModels (_: longContextCompaction "bcode.openai-compatible" 272000)
    // lib.optionalAttrs cfg.compaction.openAiPricingBarrier.enable (
      lib.genAttrs openAiPricingBarrierModels (_: longContextCompaction "bcode.openai-compatible" 272000)
    )
    // {
      # GPT-6 Astra and GPT-5.6 models (1M context) - compact at 272k
      "openai.gpt-6-astra" = longContextCompaction "bcode.bedrock" 272000;
      "us.openai.gpt-6-astra" = longContextCompaction "bcode.bedrock" 272000;
      "global.openai.gpt-6-astra" = longContextCompaction "bcode.bedrock" 272000;
      "openai.gpt-5.6-sol" = longContextCompaction "bcode.bedrock" 272000;
      "us.openai.gpt-5.6-sol" = longContextCompaction "bcode.bedrock" 272000;
      "global.openai.gpt-5.6-sol" = longContextCompaction "bcode.bedrock" 272000;
      "openai.gpt-5.6-terra" = longContextCompaction "bcode.bedrock" 272000;
      "us.openai.gpt-5.6-terra" = longContextCompaction "bcode.bedrock" 272000;
      "eu.openai.gpt-5.6-terra" = longContextCompaction "bcode.bedrock" 272000;
      "global.openai.gpt-5.6-terra" = longContextCompaction "bcode.bedrock" 272000;
      "openai.gpt-5.6-luna" = longContextCompaction "bcode.bedrock" 272000;
      "us.openai.gpt-5.6-luna" = longContextCompaction "bcode.bedrock" 272000;
      "apac.openai.gpt-5.6-luna" = longContextCompaction "bcode.bedrock" 272000;
      "global.openai.gpt-5.6-luna" = longContextCompaction "bcode.bedrock" 272000;
      "openai.gpt-5.6-cyber" = longContextCompaction "bcode.bedrock" 272000;
      "us.openai.gpt-5.6-cyber" = longContextCompaction "bcode.bedrock" 272000;
      "global.openai.gpt-5.6-cyber" = longContextCompaction "bcode.bedrock" 272000;
      # GPT-5.5 and 5.4 have 272k total context, no proactive compaction needed by default
    };

  compactionSettings = {
    mode = "on_overflow";
    backend = "auto";
    proactive_threshold_percent = 90;
    keep_recent_tokens = 20000;
    models = pricingBarrierCompactionModels;
  };

  # Provider configs merge with the base config, so omission would retain its model rules.
  overflowCompactionSettings = compactionSettings // {
    models = lib.mapAttrs (_: model: {
      inherit (model) provider_plugin_id;
      mode = "on_overflow";
    }) compactionSettings.models;
  };

  withFullContextVariant =
    profile:
    profile
    // {
      variants =
        (profile.variants or { })
        // {
          full.compaction = overflowCompactionSettings;
        }
        // lib.optionalAttrs (profile ? variants.fast) {
          full-fast = profile.variants.fast // {
            compaction = overflowCompactionSettings;
          };
        };
    };

  baseSettings = {
    plugins.enabled = [
      "bcode.openai-compatible"
      "bcode.bedrock"
    ];

    worktree.setup.direnv_allow = true;

    metrics = {
      enabled = true;
      # Retain cold-start attribution independently of the busy runtime event timeline.
      startup_reports = true;
      persist_events = true;
      segment_max_bytes = 8 * 1024 * 1024;
      total_max_bytes = 128 * 1024 * 1024;
      recent_read_max_bytes = 16 * 1024 * 1024;
      max_recent_events = 10000;
    };

    tui.keybindings.chat = {
      enter = "tui.input.newLine";
      "ctrl+enter" = "tui.input.submitSteering";
      "ctrl+shift+enter" = "tui.input.submitFollowUp";
    };

    model = {
      compaction = compactionSettings;

      # Set reasoning default to "medium" for all GPT models
      metadata."gpt-6-sol".reasoning.default_effort = "medium";
      metadata."gpt-6-luna".reasoning.default_effort = "medium";
      metadata."gpt-6-astra".reasoning.default_effort = "medium";
      metadata."openai.gpt-6-astra".reasoning.default_effort = "medium";
      metadata."us.openai.gpt-6-astra".reasoning.default_effort = "medium";
      metadata."global.openai.gpt-6-astra".reasoning.default_effort = "medium";
      metadata."gpt-5.6-sol".reasoning.default_effort = "medium";
      metadata."us.openai.gpt-5.6-sol".reasoning.default_effort = "medium";
      metadata."global.openai.gpt-5.6-sol".reasoning.default_effort = "medium";
      metadata."gpt-5.6-terra".reasoning.default_effort = "medium";
      metadata."us.openai.gpt-5.6-terra".reasoning.default_effort = "medium";
      metadata."global.openai.gpt-5.6-terra".reasoning.default_effort = "medium";
      metadata."gpt-5.6-luna".reasoning.default_effort = "medium";
      metadata."us.openai.gpt-5.6-luna".reasoning.default_effort = "medium";
      metadata."global.openai.gpt-5.6-luna".reasoning.default_effort = "medium";
      metadata."gpt-5.5".reasoning.default_effort = "medium";
      metadata."us.openai.gpt-5.5".reasoning.default_effort = "medium";
      metadata."global.openai.gpt-5.5".reasoning.default_effort = "medium";
      metadata."gpt-5.4".reasoning.default_effort = "medium";
      metadata."us.openai.gpt-5.4".reasoning.default_effort = "medium";
      metadata."global.openai.gpt-5.4".reasoning.default_effort = "medium";

      # Set reasoning default to "medium" for Fable 5.1
      metadata."claude-fable-5-1".reasoning.default_effort = "medium";
      metadata."anthropic.claude-fable-5-1".reasoning.default_effort = "medium";
      metadata."us.anthropic.claude-fable-5-1".reasoning.default_effort = "medium";
      metadata."global.anthropic.claude-fable-5-1".reasoning.default_effort = "medium";

      # Keep plain `bcode` credential-free. Provider-specific wrappers such as
      # `bcode-openai` and host-private profile wrappers point BCODE_CONFIG at
      # generated provider configs that contain their own scoped auth profiles.
      aliases = openAiFastAlias;
    };
  };

  finalSettingsRaw = lib.recursiveUpdate (lib.recursiveUpdate baseSettings bcodePermissions) cfg.extraSettings;
  finalSettings = normalizeBcodeAgentConfig finalSettingsRaw;

  # Only generate fast variants for models with documented Fast/priority support.
  openAiFastModels = [
    "gpt-6-astra"
    "gpt-6-sol"
    "gpt-6-luna"
    "gpt-5.6-sol"
    "gpt-5.6-terra"
    "gpt-5.6-luna"
    "gpt-5.5"
    "gpt-5.3-codex"
  ];

  openAiFastAlias = lib.genAttrs (map (model: "${model}-fast") openAiFastModels) (alias: {
    provider_plugin_id = "bcode.openai-compatible";
    display_name = "${lib.removeSuffix "-fast" alias} · Fast";
    model_id = lib.removeSuffix "-fast" alias;
    request."bcode.extension/bcode.openai-compatible".service_tier = "priority";
  });

  mkProfileOverlay =
    name: profile:
    let
      authProfile = profile.authProfile or null;
      authConfig = profile.auth or null;
      settings = profile.settings or { };
      aliases = profile.aliases or { };
      modelAlias = aliases.${profile.model} or null;
      profileCompaction = profile.compaction or compactionSettings;
      # Bcode only honors `auth_profile`, `auth_pool`, and provider `settings` on a named
      # `[model.profiles.<name>]` entry selected via `[model].profile`; the same keys placed
      # directly on `[model]` are not part of `ModelConfig` and were silently ignored, which
      # left provider overlays without any resolved auth.
      modelProfile = {
        display_name = profile.displayName or name;
        provider_plugin_id = profile.providerPluginId;
        model_id = if modelAlias != null then modelAlias.model_id else profile.model;
        request =
          (if modelAlias != null then modelAlias.request or { } else { }) // (profile.request or { });
        inherit settings;
      }
      // lib.optionalAttrs (authProfile != null) { auth_profile = authProfile; }
      // lib.optionalAttrs (profile ? authPool && profile.authPool != null) {
        auth_pool = profile.authPool;
      };
      baseOverlay = {
        model = {
          profile = name;
          profiles.${name} = modelProfile;
          inherit aliases;
          compaction = profileCompaction;
        };
      }
      // lib.optionalAttrs (authProfile != null && authConfig != null) {
        auth.profiles.${authProfile} = authConfig;
      };
    in
    lib.recursiveUpdate baseOverlay (profile.extraConfig or { });

  profileWithoutVariants = profile: removeAttrs profile [ "variants" ];

  mergeProfileVariant =
    profile: variant: lib.recursiveUpdate (profileWithoutVariants profile) variant;

  expandProfileOverlays =
    name: profile:
    let
      baseProfile = profileWithoutVariants profile;
      variants = profile.variants or { };
    in
    {
      ${name} = mkProfileOverlay name baseProfile;
    }
    // lib.mapAttrs' (variantName: variant: {
      name = "${name}-${variantName}";
      value = mkProfileOverlay "${name}-${variantName}" (mergeProfileVariant profile variant);
    }) variants;

  mkProfileOverlays =
    profiles:
    lib.foldl' (acc: name: acc // expandProfileOverlays name profiles.${name}) { } (
      lib.attrNames profiles
    );

  expandProfileSshenv =
    name: profile:
    let
      baseProfile = profileWithoutVariants profile;
      variants = profile.variants or { };
      base = lib.optionalAttrs (baseProfile ? sshenv && baseProfile.sshenv != null) {
        ${name} = baseProfile.sshenv;
      };
    in
    base
    // lib.concatMapAttrs (
      variantName: variant:
      let
        merged = mergeProfileVariant profile variant;
      in
      lib.optionalAttrs (merged ? sshenv && merged.sshenv != null) {
        "${name}-${variantName}" = merged.sshenv;
      }
    ) variants;

  mkProfileSshenv =
    profiles:
    lib.foldl' (acc: name: acc // expandProfileSshenv name profiles.${name}) { } (
      lib.attrNames profiles
    );

  # Shared scaffolding for the Bedrock wrappers. Every Bedrock profile authenticates through the
  # same sshenv `bedrock` profile, so they differ only by model, transport settings, and whether the
  # selected surface needs full AWS credentials or just the Mantle bearer token.
  mkBedrockProfile =
    {
      model,
      settings ? { },
      bearerOnly ? false,
    }:
    {
      providerPluginId = "bcode.bedrock";
      inherit model;
      authProfile = "bedrock";
      settings =
        settings
        // lib.optionalAttrs (cfg.providers.bedrock.region != null) {
          region = cfg.providers.bedrock.region;
        };
      auth = {
        backend = "sshenv";
        scheme = "aws_credentials";
        # The Mantle surfaces authenticate with a bearer token only; ConverseStream also accepts
        # sigv4 credentials.
        map = {
          bearer_token.env = "AWS_BEARER_TOKEN_BEDROCK";
        }
        // lib.optionalAttrs (!bearerOnly) {
          access_key_id.env = "AWS_ACCESS_KEY_ID";
          secret_access_key.env = "AWS_SECRET_ACCESS_KEY";
          session_token.env = "AWS_SESSION_TOKEN";
        };
        settings = {
          provider = "aws";
          profile =
            if cfg.providers.bedrock.sshenv != null then cfg.providers.bedrock.sshenv.profile else "bedrock";
        }
        // lib.optionalAttrs (cfg.providers.bedrock.awsProfile != null) {
          profile = cfg.providers.bedrock.awsProfile;
        }
        // lib.optionalAttrs (cfg.providers.bedrock.region != null) {
          region = cfg.providers.bedrock.region;
        };
      };
      sshenv = cfg.providers.bedrock.sshenv;
    };

  mkOpenAiProfile =
    {
      model,
      authProfile,
      fastModel ?
        if authProvider == "openai" && builtins.elem model openAiFastModels then "${model}-fast" else null,
      authProvider ? "openai",
      baseUrl ? null,
      dialect ? null,
      variants ? { },
      subscriptionPriming ? cfg.providers.openai.subscriptionPriming.enable,
      authPool ? "openai",
    }:
    let
      enableSubscriptionPriming = authProvider == "openai" && subscriptionPriming;
    in
    {
      providerPluginId = "bcode.openai-compatible";
      inherit model authProfile;
      authPool = if enableSubscriptionPriming then authPool else null;
      settings =
        lib.optionalAttrs (baseUrl != null) { base_url = baseUrl; }
        // lib.optionalAttrs (dialect != null) { inherit dialect; };
      aliases = openAiFastAlias;
      auth = {
        backend = "sshenv";
        provider_id = authProvider;
        owner_plugin_id = "bcode.openai-compatible";
        scheme = if authProvider == "openai" then "chatgpt" else "api_key";
        settings = {
          provider = authProvider;
          profile = authProfile;
          vault = cfg.authVaultPath;
        }
        // lib.optionalAttrs (authProvider == "openai") { mode = "chatgpt"; }
        // lib.optionalAttrs (baseUrl != null) { base_url = baseUrl; };
      };
      extraConfig = lib.optionalAttrs enableSubscriptionPriming {
        auth.pools.${authPool} = {
          provider_plugin_id = "bcode.openai-compatible";
          priming.enabled = true;
        };
      };
      variants =
        variants
        // lib.optionalAttrs (fastModel != null) {
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
        provider_id = authProvider;
        owner_plugin_id = "bcode.openai-compatible";
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
    // lib.optionalAttrs (sshenv != null) { inherit sshenv; };

  mkSshenvOption =
    defaultProfile: defaultValue:
    lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            profile = lib.mkOption {
              type = lib.types.str;
              default = defaultProfile;
              description = "sshenv profile to load before starting this Bcode provider wrapper.";
            };

            envOnly = lib.mkOption {
              type = lib.types.bool;
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
    # Bedrock-hosted OpenAI models live only on the Mantle Responses surface. Routing is per-model:
    # the catalog marks them `api_surface = "responses"`, so no transport pin is needed and other
    # models selected in-session still route over their own surface. `mantle_base_url` is left unset
    # so the plugin derives the flavor-correct endpoint from the region.
    bedrock-openai = withFullContextVariant (mkBedrockProfile {
      model = cfg.providers.bedrock.openaiModel;
      bearerOnly = true;
    });

    bedrock-astra = withFullContextVariant (mkBedrockProfile {
      model = cfg.providers.bedrock.astraModel;
      bearerOnly = true;
    });

    bedrock-luna = withFullContextVariant (mkBedrockProfile {
      model = cfg.providers.bedrock.lunaModel;
      bearerOnly = true;
    });

    # Fable 5.1 is catalog-routed over the Anthropic Messages surface. Keep the transport unpinned
    # so selecting another model in-session still uses that model's declared Bedrock surface.
    bedrock-fable = mkBedrockProfile {
      model = cfg.providers.bedrock.fableModel;
      bearerOnly = true;
    };

    bedrock-opus = mkBedrockProfile {
      model = cfg.providers.bedrock.opusModel;
    };

    bedrock-mantle = mkBedrockProfile {
      model = cfg.providers.bedrock.mantleModel;
      bearerOnly = true;
      settings = {
        transport = "mantle_anthropic";
        mantle_base_url = "https://bedrock-mantle.us-east-1.api.aws/anthropic";
      };
    };

    openai = mkOpenAiProfile {
      model = cfg.providers.openai.model;
      fastModel = cfg.providers.openai.fastModel;
      authProfile = cfg.providers.openai.authProfile;
      authProvider = "openai";
      dialect = "chatgpt_codex";
    };

    astra = withFullContextVariant (mkOpenAiProfile {
      model = cfg.providers.astra.model;
      authProfile = cfg.providers.astra.authProfile;
      authProvider = "openai";
      dialect = "chatgpt_codex";
    });

    luna = withFullContextVariant (mkOpenAiProfile {
      model = cfg.providers.luna.model;
      authProfile = cfg.providers.luna.authProfile;
      authProvider = "openai";
      dialect = "chatgpt_codex";
    });

    terra = withFullContextVariant (mkOpenAiProfile {
      model = cfg.providers.terra.model;
      authProfile = cfg.providers.terra.authProfile;
      authProvider = "openai";
      dialect = "chatgpt_codex";
    });

    sol = withFullContextVariant (mkOpenAiProfile {
      model = cfg.providers.sol.model;
      authProfile = cfg.providers.sol.authProfile;
      authProvider = "openai";
      dialect = "chatgpt_codex";
    });

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

    grok-4-6 =
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

  providerSshenv = lib.filterAttrs (_name: spec: spec != null) (
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
        exec ${pkgs.sshenv}/bin/sshenv run ${lib.escapeShellArg sshenvSpec.profile} -- ${command}
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
    enable = lib.mkEnableOption "Bcode coding agent configuration";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.bcode or null;
      description = "Optional Bcode package to install. Set to null when Bcode is installed outside this Nix configuration.";
    };

    authVaultPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/state/bcode/auth/vault";
      description = "sshenv vault path used for Bcode OpenAI/ChatGPT authentication.";
    };

    permissionOverrides = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Bcode-specific agent permission JSON files merged after shared permission files.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Bcode TOML settings merged after generated shared agent permissions.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = ''
        Generic generated Bcode provider profiles, keyed by wrapper name without the `bcode-` prefix.

        Each profile supports fields like `providerPluginId`, `model`, `authProfile`, `auth`,
        `displayName`, `settings`, `aliases`, `variants`, `sshenv`, and `extraConfig`.
        Display names default to the expanded profile name, so variants remain
        distinguishable. A variant can override `displayName` independently.
        Variants are
        generated as `bcode-<name>-<variant>` wrappers. This is the preferred extension point for
        host-private provider/account profiles because names and auth profile IDs stay in the host
        file that defines them.
      '';
    };

    extraProviderOverlays = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Raw Bcode provider overlay TOML settings, keyed by wrapper/provider name. Prefer `profiles` for generated provider configs.";
    };

    extraProviderSshenv = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            profile = lib.mkOption {
              type = lib.types.str;
              description = "sshenv profile to load before starting this extra Bcode provider wrapper.";
            };

            envOnly = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Load the sshenv profile as process environment variables for this provider.";
            };
          };
        }
      );
      default = { };
      description = "Additional sshenv wrapper settings, keyed by extra provider/wrapper name.";
    };

    compaction.openAiPricingBarrier.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Opt in to proactive compaction at 272k for older OpenAI-compatible models whose
        total context window is 272k. GPT-6 and GPT-5.6 profiles always compact at
        272k; this also applies to the configured Bedrock variants.
      '';
    };

    providers = {
      bedrock = {
        openaiModel = lib.mkOption {
          type = lib.types.str;
          default = "us.openai.gpt-5.6-sol";
          description = ''
            Bedrock-hosted OpenAI model used by bcode-bedrock-openai.

            Sent verbatim as the Bedrock Runtime model id. OpenAI models require an inference profile
            prefix such as `us.`, `eu.`, or `apac.` rather than the bare model id.
          '';
        };

        astraModel = lib.mkOption {
          type = lib.types.str;
          default = "us.openai.gpt-6-astra";
          description = "Bedrock-hosted GPT-6 Astra model used by bcode-bedrock-astra.";
        };

        lunaModel = lib.mkOption {
          type = lib.types.str;
          default = "us.openai.gpt-5.6-luna";
          description = "Bedrock-hosted GPT-5.6 Luna model used by bcode-bedrock-luna.";
        };

        fableModel = lib.mkOption {
          type = lib.types.str;
          default = "global.anthropic.claude-fable-5-1";
          description = "Bedrock Anthropic Messages model used by bcode-bedrock-fable.";
        };

        opusModel = lib.mkOption {
          type = lib.types.str;
          default = "global.anthropic.claude-opus-5";
          description = "Native Bedrock (ConverseStream) model used by bcode-bedrock-opus.";
        };

        mantleModel = lib.mkOption {
          type = lib.types.str;
          default = "anthropic.claude-opus-5";
          description = "Anthropic Messages model used by bcode-bedrock-mantle.";
        };

        region = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional AWS region setting for the bcode-bedrock-* wrappers.";
        };

        awsProfile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional AWS profile setting for the bcode-bedrock-* wrappers.";
        };

        sshenv = mkSshenvOption "bedrock" {
          profile = "bedrock";
          envOnly = true;
        };
      };

      openai = {
        model = lib.mkOption {
          type = lib.types.str;
          default = "gpt-6-sol";
          description = "OpenAI/ChatGPT model used by bcode-openai.";
        };

        fastModel = lib.mkOption {
          type = lib.types.str;
          default = "gpt-6-sol-fast";
          description = "Priority-tier OpenAI/ChatGPT model alias used by bcode-openai-fast.";
        };

        authProfile = lib.mkOption {
          type = lib.types.str;
          default = "openai";
          description = "Shared sshenv profile used by bcode-openai.";
        };

        sshenv = mkSshenvOption "openai" null;

        subscriptionPriming = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Bcode's OpenAI/Codex subscription priming defaults for bcode-openai.";
          };
        };
      };

      astra = {
        model = lib.mkOption {
          type = lib.types.str;
          default = "gpt-6-astra";
          description = "GPT-6 Astra model used by bcode-astra.";
        };

        authProfile = lib.mkOption {
          type = lib.types.str;
          default = "openai";
          description = "Shared sshenv profile used by bcode-astra.";
        };

        sshenv = mkSshenvOption "openai" null;
      };

      luna = {
        model = lib.mkOption {
          type = lib.types.str;
          default = "gpt-6-luna";
          description = "GPT-6 Luna model used by bcode-luna.";
        };

        authProfile = lib.mkOption {
          type = lib.types.str;
          default = "openai";
          description = "Shared sshenv profile used by bcode-luna.";
        };

        sshenv = mkSshenvOption "openai" null;
      };

      terra = {
        model = lib.mkOption {
          type = lib.types.str;
          default = "gpt-5.6-terra";
          description = "GPT-5.6 Terra model used by bcode-terra.";
        };

        authProfile = lib.mkOption {
          type = lib.types.str;
          default = "openai";
          description = "Shared sshenv profile used by bcode-terra.";
        };

        sshenv = mkSshenvOption "openai" null;
      };

      sol = {
        model = lib.mkOption {
          type = lib.types.str;
          default = "gpt-6-sol";
          description = "GPT-6 Sol model used by bcode-sol.";
        };

        authProfile = lib.mkOption {
          type = lib.types.str;
          default = "openai";
          description = "Shared sshenv profile used by bcode-sol.";
        };

        sshenv = mkSshenvOption "openai" null;
      };

      codex = {
        model = lib.mkOption {
          type = lib.types.str;
          default = "gpt-5.3-codex";
          description = "Codex model used by bcode-codex.";
        };

        authProfile = lib.mkOption {
          type = lib.types.str;
          default = "openai";
          description = "Shared sshenv profile used by bcode-codex.";
        };

        sshenv = mkSshenvOption "openai" null;
      };

      xai = {
        model = lib.mkOption {
          type = lib.types.str;
          default = "grok-4.6";
          description = "xAI/Grok model used by bcode-xai.";
        };

        codeFastModel = lib.mkOption {
          type = lib.types.str;
          default = "grok-code-fast";
          description = "xAI/Grok Code Fast model used by bcode-grok-code-fast.";
        };

        sshenv = mkSshenvOption "xai" {
          profile = "xai";
          envOnly = true;
        };
      };

      openrouter = {
        model = lib.mkOption {
          type = lib.types.str;
          default = "z-ai/glm-5.1";
          description = "OpenRouter model used by bcode-openrouter.";
        };

        baseUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://openrouter.ai/api/v1";
          description = "OpenRouter OpenAI-compatible API base URL.";
        };

        authProfile = lib.mkOption {
          type = lib.types.str;
          default = "openrouter";
          description = "sshenv auth profile used by bcode-openrouter.";
        };

        authVaultPath = lib.mkOption {
          type = lib.types.str;
          default = cfg.authVaultPath;
          description = "sshenv vault path used by bcode-openrouter.";
        };

        apiKeyEnv = lib.mkOption {
          type = lib.types.str;
          default = "OPENROUTER_API_KEY";
          description = "API key environment variable loaded from the bcode-openrouter sshenv profile.";
        };

        sshenv = mkSshenvOption "openrouter" {
          profile = "openrouter";
          envOnly = true;
        };
      };

      zen = {
        model = lib.mkOption {
          type = lib.types.str;
          default = "big-pickle";
          description = "OpenCode Zen model used by bcode-zen.";
        };

        baseUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://opencode.ai/zen/v1";
          description = "OpenCode Zen OpenAI-compatible API base URL.";
        };

        authProfile = lib.mkOption {
          type = lib.types.str;
          default = "opencode-zen";
          description = "sshenv auth profile used by bcode-zen.";
        };

        authVaultPath = lib.mkOption {
          type = lib.types.str;
          default = cfg.authVaultPath;
          description = "sshenv vault path used by bcode-zen.";
        };

        apiKeyEnv = lib.mkOption {
          type = lib.types.str;
          default = "OPENCODE_API_KEY";
          description = "API key environment variable loaded from the bcode-zen sshenv profile.";
        };

        sshenv = mkSshenvOption "opencode-zen" {
          profile = "opencode-zen";
          envOnly = true;
        };
      };

      brouter = {
        model = lib.mkOption {
          type = lib.types.str;
          default = brouterCfg.defaultModel;
          description = "Model used by bcode-brouter against the local brouter OpenAI-compatible endpoint.";
        };

        sshenv = mkSshenvOption "brouter" null;
      };

      brouterProxy = {
        model = lib.mkOption {
          type = lib.types.str;
          default = brouterProxyCfg.defaultModel;
          description = "Model used by bcode-brouter-proxy against the local brouter-proxy OpenAI-compatible endpoint.";
        };

        sshenv = mkSshenvOption "brouter-proxy" null;
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = lib.mapAttrsToList (name: spec: {
          assertion = spec.envOnly;
          message = "Bcode provider '${name}' only supports sshenv.envOnly = true.";
        }) providerSshenv;

        home.packages = lib.optional (cfg.package != null) cfg.package;

        xdg.configFile."bcode/bcode.toml".source = tomlFormat.generate "bcode.toml" finalSettings;
        xdg.configFile."bcode/skills".source = skillsDir;

        myConfig.shell.contrib.functions = providerWrapperCommands;
      }
      {
        xdg.configFile = lib.mapAttrs' (name: overlay: {
          name = "bcode/providers/${name}.toml";
          value.source = tomlFormat.generate "bcode-provider-${name}.toml" overlay;
        }) providerOverlays;
      }
    ]
  );
}
