{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myConfig.development.opencode;
  agentsCfg = config.myConfig.development.agents;
  brouterCfg = config.myConfig.development.brouter;
  brouterProxyCfg = config.myConfig.development.brouterProxy;

  brouterOpencode = import ../../lib/brouter-opencode-provider.nix { };
  agentPermissions = import ../../lib/agent-permissions.nix { inherit lib; };

  # Auto-discover provider profiles from configs/opencode/providers/
  providersDir = ../../../configs/opencode/providers;
  allProviderFiles = builtins.attrNames (builtins.readDir providersDir);
  jsonProviderFiles = builtins.filter (f: lib.hasSuffix ".json" f) allProviderFiles;
  jsonProviderNames = map (f: lib.removeSuffix ".json" f) jsonProviderFiles;
  jsonProviderConfigs = lib.listToAttrs (
    map (name: {
      inherit name;
      value = builtins.fromJSON (builtins.readFile (providersDir + "/${name}.json"));
    }) jsonProviderNames
  );
  generatedProviderConfigs = lib.optionalAttrs (jsonProviderConfigs ? openai) {
    openai-fast = lib.recursiveUpdate jsonProviderConfigs.openai {
      model = "openai/gpt-5.5-fast";
      agent = {
        build.model = "openai/gpt-5.5-fast";
        plan.model = "openai/gpt-5.5-fast";
        explore.model = "openai/gpt-5.5-fast";
        general.model = "openai/gpt-5.5-fast";
        summary.model = "openai/gpt-5.5-fast";
        compaction.model = "openai/gpt-5.5-fast";
      };
    };
  };
  providerConfigs = jsonProviderConfigs // generatedProviderConfigs;
  providerNames = builtins.attrNames providerConfigs;

  providerWrapperCommands = builtins.listToAttrs (
    map (name: {
      name = "opencode-${name}";
      value = ''
        OPENCODE_CONFIG="$HOME/.config/opencode/providers/${name}.json" opencode-dev "$@"
      '';
    }) providerNames
  );

  mkAliasWrapper =
    name: alias:
    let
      authEnv = lib.optionalString alias.ignorePersistedAuth "OPENCODE_AUTH_CONTENT={} ";
      command = ''
        env OPENCODE_CONFIG="$HOME/.config/opencode/providers/${alias.provider}.json" ${authEnv}opencode-dev "$@"
      '';
    in
    if alias.sshenvProfile == null then
      command
    else
      ''
        sshenv run ${lib.escapeShellArg alias.sshenvProfile} -- ${command}
      '';

  aliasWrapperCommands = lib.mapAttrs' (name: alias: {
    name = "opencode-${name}";
    value = mkAliasWrapper name alias;
  }) cfg.aliases;

  # Read and parse the selected provider config
  providerConfig = providerConfigs.${cfg.provider};

  # Auto-discover shared agent permission files from configs/agents/permissions/
  permissionsDir = ../../../configs/agents/permissions;

  # Auto-discover shared agent skill directories from configs/agents/skills/
  skillsDir = ../../../configs/agents/skills;
  skillEntries = builtins.attrNames (builtins.readDir skillsDir);

  # Filter to actual skill directories (exclude _shared and non-skill entries)
  isSkillDir =
    name:
    let
      dirContents = builtins.readDir (skillsDir + "/${name}");
    in
    name != "_shared" && builtins.hasAttr "SKILL.md" dirContents;
  localSkillNames = builtins.filter isSkillDir skillEntries;

  # Extract description from a SKILL.md file's YAML frontmatter
  parseSkillDescription =
    skillMdPath:
    let
      content = builtins.readFile skillMdPath;
      matched = builtins.match "---\nname: ([^\n]+)\ndescription: ([^\n]+)\n.*" content;
    in
    if matched != null then builtins.elemAt matched 1 else "Run this skill";

  # Generate a command markdown file that invokes the skill
  makeSkillCommand =
    name: description: "---\ndescription: ${description}\n---\n/skill ${name} $ARGUMENTS\n";

  # Build command entries for all local skills
  localSkillCommands = builtins.listToAttrs (
    map (name: {
      name = "opencode/commands/${name}.md";
      value = {
        text = makeSkillCommand name (parseSkillDescription (skillsDir + "/${name}/SKILL.md"));
      };
    }) localSkillNames
  );

  # Build command entry for tone-clone (external skill)
  toneCloneCommand = {
    "opencode/commands/tone-clone.md" = {
      text = makeSkillCommand "tone-clone" (
        parseSkillDescription "${inputs.tone-clone-src}/skills/tone-clone/SKILL.md"
      );
    };
  };

  brouterProviderConfig = brouterOpencode.mkProvider {
    providerName = brouterCfg.providerName;
    baseURL = "http://${brouterCfg.host}:${toString brouterCfg.port}/v1";
    displayName = "BRouter";
    defaultModel = brouterCfg.defaultModel;
  };
  brouterProxyProviderConfig = brouterOpencode.mkProvider {
    providerName = brouterProxyCfg.providerName;
    baseURL = "http://${brouterProxyCfg.host}:${toString brouterProxyCfg.port}/v1";
    displayName = brouterProxyCfg.displayName;
    defaultModel = brouterProxyCfg.defaultModel;
  };

  # Merge order: base → provider → shared permissions → host overrides (in order)
  baseConfig = builtins.fromJSON (builtins.readFile ../../../configs/opencode/opencode.json);
  tuiConfig = ../../../configs/opencode/tui.json;
  permissionConfig = agentPermissions.mkPermissions {
    inherit permissionsDir;
    cfg = agentsCfg.permissions;
    overrides = agentsCfg.permissions.overrides ++ cfg.overrides;
  };
  mergedConfigBase = lib.foldl' lib.recursiveUpdate baseConfig [
    providerConfig
    permissionConfig
  ];
  mergedConfig =
    let
      withBrouter =
        if brouterCfg.enable && brouterCfg.enableOpenCodeIntegration && brouterCfg.makeOpenCodeDefault then
          lib.recursiveUpdate mergedConfigBase brouterProviderConfig
        else
          mergedConfigBase;
    in
    if
      brouterProxyCfg.enable
      && brouterProxyCfg.enableOpenCodeIntegration
      && brouterProxyCfg.makeOpenCodeDefault
    then
      lib.recursiveUpdate withBrouter brouterProxyProviderConfig
    else
      withBrouter;

  # Ollama provider config (only when ollama is enabled)
  ollamaCfg = config.myConfig.tools.ai.ollama;
  ollamaModels = lib.unique ([ ollamaCfg.model ] ++ ollamaCfg.extraModels);
  ollamaModel = "ollama/${ollamaCfg.model}";
  ollamaModelRegistry = builtins.listToAttrs (
    map (model: {
      name = model;
      value = {
        name = model;
      };
    }) ollamaModels
  );
  ollamaProviderConfig = {
    provider.ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama";
      options = {
        baseURL = ollamaCfg.serverUrl;
        apiKey = "ollama";
      };
      models = ollamaModelRegistry;
    };
    model = ollamaModel;
    small_model = ollamaModel;
    agent = {
      build.model = ollamaModel;
      plan.model = ollamaModel;
      explore.model = ollamaModel;
      general.model = ollamaModel;
      title.model = ollamaModel;
      summary.model = ollamaModel;
      compaction.model = ollamaModel;
    };
  };

  # Base OLLAMA_HOST is serverUrl minus /v1 suffix
  ollamaHost =
    let
      url = ollamaCfg.serverUrl;
    in
    if lib.hasSuffix "/v1" url then lib.substring 0 (lib.stringLength url - 3) url else url;
in
{
  options.myConfig.development.opencode = {
    enable = lib.mkEnableOption "OpenCode AI assistant configuration";

    provider = lib.mkOption {
      type = lib.types.enum providerNames;
      default = "openai";
      description = "OpenCode provider profile to use (matches filename in configs/opencode/providers/ without .json)";
    };

    overrides = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "List of JSON files to deep-merge over the base config (e.g., host-specific encrypted overrides)";
    };

    aliases = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            provider = lib.mkOption {
              type = lib.types.enum providerNames;
              description = "Provider profile to use for this OpenCode alias";
            };

            sshenvProfile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional sshenv profile to load before starting OpenCode";
            };

            ignorePersistedAuth = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Ignore ~/.local/share/opencode/auth.json for this alias so env credentials win";
            };
          };
        }
      );
      default = { };
      description = "Additional opencode-<name> wrapper commands for provider and credential variants";
    };

  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        xdg.configFile."opencode/opencode.json".text = builtins.toJSON mergedConfig;
        xdg.configFile."opencode/tui.json".source = tuiConfig;
      }

      # Auto-discover and deploy all shared agent skill directories from configs/agents/skills/
      {
        xdg.configFile = builtins.listToAttrs (
          map (name: {
            name = "opencode/skills/${name}";
            value = {
              source = skillsDir + "/${name}";
              recursive = true;
            };
          }) skillEntries
        );
      }

      # Deploy tone-clone skill from external repo and install the CLI
      {
        xdg.configFile."opencode/skills/tone-clone" = {
          source = "${inputs.tone-clone-src}/skills/tone-clone";
          recursive = true;
        };
        home.packages = [
          pkgs.opencode-dev
          pkgs.tone-clone
        ];
      }

      # Auto-generate slash commands for all skills (local + external)
      {
        xdg.configFile = localSkillCommands // toneCloneCommand;
      }

      # Deploy raw/generated provider files for per-provider wrapper commands (opencode-bedrock, opencode-copilot, etc.)
      {
        xdg.configFile =
          (builtins.listToAttrs (
            map (name: {
              name = "opencode/providers/${name}.json";
              value = {
                source = providersDir + "/${name}.json";
              };
            }) jsonProviderNames
          ))
          // (lib.mapAttrs' (name: providerConfig: {
            name = "opencode/providers/${name}.json";
            value.text = builtins.toJSON providerConfig;
          }) generatedProviderConfigs);
      }

      # Cross-shell wrapper commands for switching provider profiles
      {
        myConfig.shell.contrib.functions = providerWrapperCommands // aliasWrapperCommands;
      }

      # Conditional Ollama provider (only when tools.ai.ollama is enabled)
      (lib.mkIf ollamaCfg.enable {
        xdg.configFile."opencode/providers/ollama.json".text = builtins.toJSON ollamaProviderConfig;
        myConfig.shell.contrib.functions.opencode-ollama = ''
          OLLAMA_HOST=${lib.escapeShellArg ollamaHost} OPENCODE_CONFIG="$HOME/.config/opencode/providers/ollama.json" opencode-dev "$@"
        '';
        home.sessionVariables.OLLAMA_HOST = ollamaHost;
      })

      # Conditional brouter provider. It is available as opencode-brouter even
      # when it is not the default OpenCode config.
      (lib.mkIf (brouterCfg.enable && brouterCfg.enableOpenCodeIntegration) {
        xdg.configFile."opencode/providers/${brouterCfg.providerName}.json".text =
          builtins.toJSON brouterProviderConfig;
        myConfig.shell.contrib.functions."opencode-${brouterCfg.providerName}" = ''
          OPENCODE_CONFIG="$HOME/.config/opencode/providers/${brouterCfg.providerName}.json" opencode-dev "$@"
        '';
      })

      # Conditional brouter-proxy provider. Available as opencode-brouter-proxy
      # even when it is not the default OpenCode config.
      (lib.mkIf (brouterProxyCfg.enable && brouterProxyCfg.enableOpenCodeIntegration) {
        xdg.configFile."opencode/providers/${brouterProxyCfg.providerName}.json".text =
          builtins.toJSON brouterProxyProviderConfig;
        myConfig.shell.contrib.functions."opencode-${brouterProxyCfg.providerName}" = ''
          OPENCODE_CONFIG="$HOME/.config/opencode/providers/${brouterProxyCfg.providerName}.json" opencode-dev "$@"
        '';
      })
    ]
  );
}
