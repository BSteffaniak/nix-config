{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.myConfig.development.brouter;
  ollamaCfg = config.myConfig.tools.ai.ollama;
  tomlFormat = pkgs.formats.toml { };

  configPath = "${config.xdg.configHome}/brouter/brouter.toml";
  stateDir = "${config.home.homeDirectory}/.local/state/brouter";
  logsDir = "${config.home.homeDirectory}/Library/Logs";
  extraOllamaModels = builtins.filter (model: model != ollamaCfg.model) ollamaCfg.extraModels;

  mkLocalModel = model: quality: {
    provider = "ollama";
    inherit model quality;
    context_window = 131072;
    input_cost_per_million = 0.0;
    output_cost_per_million = 0.0;
    capabilities = [
      "chat"
      "code"
      "local"
      "reasoning"
    ];
  };

  localModels = optionalAttrs ollamaCfg.enable (
    {
      local_primary = mkLocalModel ollamaCfg.model 75;
    }
    // builtins.listToAttrs (
      imap0 (index: model: {
        name = "local_extra_${toString index}";
        value = mkLocalModel model 65;
      }) extraOllamaModels
    )
  );

  mkOpenaiMaxModel = upstreamModel: quality: latencyClass: {
    provider = "openai_max";
    model = upstreamModel;
    context_window = 1050000;
    input_cost_per_million = 0.0;
    output_cost_per_million = 0.0;
    inherit quality;
    capabilities = [
      "chat"
      "code"
      "json"
      "tools"
      "reasoning"
    ];
    attributes = {
      latency_class = latencyClass;
      billing_class = "subscription";
    };
    display_badges = [ latencyClass ];
  };

  openaiMaxModels = optionalAttrs cfg.openaiMax.enable {
    openai_max_fast = mkOpenaiMaxModel cfg.openaiMax.fastModel 96 "standard";
    openai_max_fast_priority = mkOpenaiMaxModel cfg.openaiMax.fastModel 96 "priority";
    openai_max_strong = mkOpenaiMaxModel cfg.openaiMax.strongModel 98 "standard";
    openai_max_strong_priority = mkOpenaiMaxModel cfg.openaiMax.strongModel 98 "priority";
  };

  openaiModels = optionalAttrs cfg.openai.enable {
    cheap_cloud = {
      provider = "openai";
      model = cfg.openai.fastModel;
      context_window = 128000;
      input_cost_per_million = 0.15;
      output_cost_per_million = 0.60;
      quality = 70;
      capabilities = [
        "chat"
        "json"
        "tools"
      ];
    };

    strong_cloud = {
      provider = "openai";
      model = cfg.openai.strongModel;
      context_window = 128000;
      input_cost_per_million = 2.00;
      output_cost_per_million = 8.00;
      quality = 90;
      capabilities = [
        "chat"
        "code"
        "json"
        "tools"
        "reasoning"
      ];
    };

    embedding_cloud = {
      provider = "openai";
      model = cfg.openai.embeddingModel;
      context_window = 8192;
      input_cost_per_million = 0.02;
      output_cost_per_million = 0.0;
      quality = 70;
      capabilities = [ "embeddings" ];
    };
  };

  mkOpenrouterModel = upstreamModel: quality: latencyClass: {
    provider = "openrouter";
    model = upstreamModel;
    context_window = 128000;
    input_cost_per_million = 0.0;
    output_cost_per_million = 0.0;
    inherit quality;
    capabilities = [
      "chat"
      "code"
      "json"
      "tools"
      "reasoning"
    ];
    attributes = {
      latency_class = latencyClass;
      billing_class = "subscription";
    };
    display_badges = [ latencyClass ];
  };

  openrouterModels = optionalAttrs cfg.openrouter.enable {
    openrouter_fast = mkOpenrouterModel cfg.openrouter.fastModel 85 "standard";
    openrouter_fast_priority = mkOpenrouterModel cfg.openrouter.fastModel 85 "priority";
    openrouter_strong = mkOpenrouterModel cfg.openrouter.strongModel 92 "standard";
    openrouter_strong_priority = mkOpenrouterModel cfg.openrouter.strongModel 92 "priority";
  };

  mkOpencodeZenModel = upstreamModel: quality: latencyClass: {
    provider = "opencode_zen";
    model = upstreamModel;
    context_window = 128000;
    input_cost_per_million = 0.0;
    output_cost_per_million = 0.0;
    inherit quality;
    capabilities = [
      "chat"
      "code"
      "json"
      "tools"
      "reasoning"
    ];
    attributes = {
      latency_class = latencyClass;
      billing_class = "subscription";
    };
    display_badges = [ latencyClass ];
  };

  opencodeZenModels = optionalAttrs cfg.opencodeZen.enable {
    opencode_zen_fast = mkOpencodeZenModel cfg.opencodeZen.fastModel 88 "standard";
    opencode_zen_fast_priority = mkOpencodeZenModel cfg.opencodeZen.fastModel 88 "priority";
    opencode_zen_strong = mkOpencodeZenModel cfg.opencodeZen.strongModel 93 "standard";
    opencode_zen_strong_priority = mkOpencodeZenModel cfg.opencodeZen.strongModel 93 "priority";
  };

  primaryFastModel =
    if ollamaCfg.enable then
      "local_primary"
    else if cfg.openaiMax.enable then
      "openai_max_fast"
    else if cfg.openrouter.enable then
      "openrouter_fast"
    else if cfg.opencodeZen.enable then
      "opencode_zen_fast"
    else if cfg.openai.enable then
      "cheap_cloud"
    else
      "local_primary";

  primaryStrongModel =
    if cfg.openaiMax.enable then
      "openai_max_strong"
    else if cfg.openrouter.enable then
      "openrouter_strong"
    else if cfg.opencodeZen.enable then
      "opencode_zen_strong"
    else if cfg.openai.enable then
      "strong_cloud"
    else if ollamaCfg.enable then
      "local_primary"
    else
      "local_primary";

  baseSettings = {
    server = {
      inherit (cfg) host port;
      max_request_body_bytes = cfg.maxRequestBodyBytes;
    };

    router = {
      default_objective = "balanced";
      debug_headers = true;
      provider_failure_threshold = 3;
      provider_cooldown_ms = 30000;
      aliases = {
        fast = primaryFastModel;
        strong = primaryStrongModel;
      };
      scoring = {
        quality_weight = 1.0;
        balanced_cost_weight = 20.0;
        cheapest_cost_weight = 100.0;
        local_bonus = 10.0;
        strongest_quality_weight = 0.5;
        first_message_reasoning_bonus = 8.0;
        code_bonus = 15.0;
        reasoning_bonus = 20.0;
      };
      llm_judge = {
        model = primaryFastModel;
        provider =
          if cfg.openaiMax.enable then
            "openai_max"
          else if cfg.openrouter.enable then
            "openrouter"
          else if cfg.opencodeZen.enable then
            "opencode_zen"
          else if cfg.openai.enable then
            "openai"
          else
            "ollama";
        trigger = {
          score_gap_threshold = 5.0;
          rule_triggered = true;
        };
        shortlist = {
          size = 5;
          min_score = 0.0;
        };
        output = {
          structured = true;
          max_tokens = 256;
          temperature = 0.0;
        };
        budget = {
          max_estimated_cost = 0.0;
        };
      };
      rules =
        (optional ollamaCfg.enable {
          name = "private-local";
          when_contains = [
            "secret"
            "private key"
            "credentials"
          ];
          objective = "local_only";
          require_capabilities = [ "local" ];
        })
        ++ [
          {
            name = "debug-code-reasoning";
            intent = "debugging";
            prefer_capabilities = [ "reasoning" ];
          }
          {
            name = "explicit-priority";
            when_contains = [
              "priority"
              "urgent"
              "asap"
              "low latency"
              "quick response"
            ];
            prefer_attributes.latency_class = "priority";
          }
          {
            name = "summaries-standard";
            intent = "summarization";
            prefer_attributes.latency_class = "standard";
          }
        ];
    }
    // optionalAttrs (cfg.openai.enable || cfg.openaiMax.enable) {
      groups = {
        cloud =
          (optional cfg.openaiMax.enable "openai_max_fast")
          ++ (optional cfg.openaiMax.enable "openai_max_fast_priority")
          ++ (optional cfg.openaiMax.enable "openai_max_strong")
          ++ (optional cfg.openaiMax.enable "openai_max_strong_priority")
          ++ (optional cfg.openai.enable "cheap_cloud")
          ++ (optional cfg.openai.enable "strong_cloud");
        standard =
          (optional cfg.openaiMax.enable "openai_max_fast")
          ++ (optional cfg.openaiMax.enable "openai_max_strong")
          ++ (optional cfg.openai.enable "cheap_cloud")
          ++ (optional cfg.openai.enable "strong_cloud");
      }
      // optionalAttrs cfg.openaiMax.enable {
        priority = [
          "openai_max_fast_priority"
          "openai_max_strong_priority"
        ];
      };
    };

    telemetry.database_path = "${stateDir}/brouter.db";

    providers =
      optionalAttrs ollamaCfg.enable {
        ollama = {
          kind = "open-ai-compatible";
          base_url = ollamaCfg.serverUrl;
          timeout_ms = 60000;
        };
      }
      // optionalAttrs cfg.openaiMax.enable {
        openai_max = {
          kind = "openai-codex";
          auth_backend = "sshenv";
          auth_profile = cfg.openaiMax.authProfile;
          auth_vault_path = cfg.openaiMax.authVaultPath;
          timeout_ms = 60000;
          attribute_mappings.latency_class = {
            priority.request_fields.service_tier = "priority";
            standard.omit_request_fields = [ "service_tier" ];
          };
        };
      }
      // optionalAttrs cfg.openai.enable {
        openai = {
          kind = "open-ai-compatible";
          base_url = "https://api.openai.com/v1";
          api_key_env = cfg.openai.apiKeyEnv;
          timeout_ms = 60000;
        };
      }
      // optionalAttrs cfg.openrouter.enable {
        openrouter = {
          kind = "open-ai-compatible";
          base_url = cfg.openrouter.baseUrl;
          api_key_env = cfg.openrouter.apiKeyEnv;
          auth_backend = "sshenv";
          auth_profile = cfg.openrouter.authProfile;
          timeout_ms = 60000;
        };
      }
      // optionalAttrs cfg.opencodeZen.enable {
        opencode_zen = {
          kind = "open-ai-compatible";
          base_url = "https://opencode.ai/zen/v1";
          api_key_env = cfg.opencodeZen.apiKeyEnv;
          auth_backend = "sshenv";
          auth_profile = cfg.opencodeZen.authProfile;
          timeout_ms = 60000;
        };
      };

    models = localModels // openaiMaxModels // openaiModels // openrouterModels // opencodeZenModels;
  };

  finalSettings = recursiveUpdate baseSettings cfg.extraSettings;
in
{
  options.myConfig.development.brouter = {
    enable = mkEnableOption "brouter local LLM router service";

    package = mkOption {
      type = types.package;
      default = pkgs.brouter;
      defaultText = literalExpression "pkgs.brouter";
      description = "brouter package to install and run.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host address for the local brouter HTTP server.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port for the local brouter HTTP server.";
    };

    maxRequestBodyBytes = mkOption {
      type = types.int;
      default = 1048576;
      description = "Maximum request body size accepted by brouter.";
    };

    enableService = mkOption {
      type = types.bool;
      default = true;
      description = "Start brouter automatically as a user service.";
    };

    enablePiIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Register brouter as a Pi custom provider and add pi-brouter.";
    };

    makePiDefault = mkOption {
      type = types.bool;
      default = false;
      description = "Make brouter the default Pi provider/model.";
    };

    enableOpenCodeIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Register brouter as an OpenCode provider and add opencode-brouter.";
    };

    makeOpenCodeDefault = mkOption {
      type = types.bool;
      default = false;
      description = "Make brouter the default OpenCode provider/model.";
    };

    providerName = mkOption {
      type = types.str;
      default = "brouter";
      description = "Provider name exposed to Pi and OpenCode.";
    };

    defaultModel = mkOption {
      type = types.str;
      default = "auto";
      description = "Default brouter model ID used by Pi/OpenCode integrations.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables injected into the brouter user service.";
    };

    sshenvProfile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "openai-api";
      description = "Optional sshenv profile used to launch the brouter service with secrets.";
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra TOML settings recursively merged into generated brouter.toml.";
    };

    openaiMax = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Add ChatGPT/Codex Max subscription auth from an sshenv vault.";
      };

      authProfile = mkOption {
        type = types.str;
        default = "openai-max";
        description = "sshenv profile containing ChatGPT/Codex OAuth tokens.";
      };

      authVaultPath = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.local/state/brouter/auth/vault";
        description = "brouter-owned sshenv vault path containing ChatGPT/Codex OAuth tokens.";
      };

      fastModel = mkOption {
        type = types.str;
        default = "gpt-5.5";
        description = "Default ChatGPT/Codex subscription model for fast routing.";
      };

      strongModel = mkOption {
        type = types.str;
        default = "gpt-5.5";
        description = "Default ChatGPT/Codex subscription model for strong routing.";
      };
    };

    openai = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Add OpenAI as a cloud upstream. The service must receive the API key env var separately.";
      };

      apiKeyEnv = mkOption {
        type = types.str;
        default = "OPENAI_API_KEY";
        description = "Environment variable brouter reads for the OpenAI API key.";
      };

      fastModel = mkOption {
        type = types.str;
        default = "gpt-4o-mini";
        description = "Lower-cost OpenAI model for fast cloud routing.";
      };

      strongModel = mkOption {
        type = types.str;
        default = "gpt-4.1";
        description = "Higher-quality OpenAI model for strong cloud routing.";
      };

      embeddingModel = mkOption {
        type = types.str;
        default = "text-embedding-3-small";
        description = "OpenAI embedding model.";
      };
    };

    openrouter = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Add OpenRouter as a cloud upstream (aggregates many model providers).";
      };

      apiKeyEnv = mkOption {
        type = types.str;
        default = "OPENROUTER_API_KEY";
        description = "Environment variable brouter reads for the OpenRouter API key (injected by sshenv vault).";
      };

      authProfile = mkOption {
        type = types.str;
        default = "openrouter";
        description = "sshenv profile containing OpenRouter API key.";
      };

      authVaultPath = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.local/state/brouter/auth/openrouter_vault";
        description = "brouter-owned sshenv vault path for OpenRouter API key.";
      };

      baseUrl = mkOption {
        type = types.str;
        default = "https://openrouter.ai/api/v1";
        description = "OpenRouter API base URL.";
      };

      fastModel = mkOption {
        type = types.str;
        default = "anthropic/claude-3.5-haiku";
        description = "OpenRouter model for fast routing.";
      };

      strongModel = mkOption {
        type = types.str;
        default = "anthropic/claude-3.7-sonnet";
        description = "OpenRouter model for strong routing.";
      };
    };

    opencodeZen = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Add OpenCode Zen as a cloud upstream (OpenCode's own LLM service).";
      };

      apiKeyEnv = mkOption {
        type = types.str;
        default = "OPENCODE_API_KEY";
        description = "Environment variable brouter reads for the OpenCode Zen API key (injected by sshenv vault).";
      };

      authProfile = mkOption {
        type = types.str;
        default = "opencode-zen";
        description = "sshenv profile containing the OpenCode Zen API key.";
      };

      authVaultPath = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.local/state/brouter/auth/opencode_zen_vault";
        description = "brouter-owned sshenv vault path for OpenCode Zen API key.";
      };

      fastModel = mkOption {
        type = types.str;
        default = "big-pickle";
        description = "OpenCode Zen model for fast routing.";
      };

      strongModel = mkOption {
        type = types.str;
        default = "big-pickle";
        description = "OpenCode Zen model for strong routing.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion =
            ollamaCfg.enable
            || cfg.openaiMax.enable
            || cfg.openai.enable
            || cfg.openrouter.enable
            || cfg.opencodeZen.enable
            || cfg.extraSettings ? providers;
          message = "myConfig.development.brouter requires at least one upstream provider: enable tools.ai.ollama, enable development.brouter.openaiMax/openai/openrouter/opencodeZen, or provide extraSettings.providers/models.";
        }
      ];

      home.packages = [ cfg.package ] ++ optional (cfg.sshenvProfile != null) pkgs.sshenv;

      xdg.configFile."brouter/brouter.toml".source = tomlFormat.generate "brouter.toml" finalSettings;

      home.activation.createBrouterStateDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${escapeShellArg stateDir}
      '';
    }

    (mkIf (cfg.enableService && pkgs.stdenv.isDarwin) {
      launchd.agents.brouter = {
        enable = true;
        config = {
          Label = "com.braden.brouter";
          ProgramArguments =
            if cfg.sshenvProfile == null then
              [
                "${cfg.package}/bin/brouter"
                "serve"
                "--config"
                configPath
              ]
            else
              [
                "${pkgs.sshenv}/bin/sshenv"
                "run"
                cfg.sshenvProfile
                "--"
                "${cfg.package}/bin/brouter"
                "serve"
                "--config"
                configPath
              ];
          RunAtLoad = true;
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          EnvironmentVariables = cfg.environment;
          StandardOutPath = "${logsDir}/brouter.launchd.log";
          StandardErrorPath = "${logsDir}/brouter.launchd.err.log";
        };
      };
    })

    (mkIf (cfg.enableService && pkgs.stdenv.isLinux) {
      systemd.user.services.brouter = {
        Unit = {
          Description = "brouter local LLM router";
          After = [ "network-online.target" ];
        };
        Service = {
          ExecStart =
            if cfg.sshenvProfile == null then
              "${cfg.package}/bin/brouter serve --config ${configPath}"
            else
              "${pkgs.sshenv}/bin/sshenv run ${escapeShellArg cfg.sshenvProfile} -- ${cfg.package}/bin/brouter serve --config ${configPath}";
          Restart = "on-failure";
          RestartSec = 5;
          Environment = mapAttrsToList (name: value: "${name}=${value}") cfg.environment;
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
  ]);
}
