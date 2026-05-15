{
  config,
  lib,
  pkgs,
  inputs,
  myLib,
  ...
}:

with lib;

let
  cfg = config.myConfig.development.pi;
  agentsCfg = config.myConfig.development.agents;
  brouterCfg = config.myConfig.development.brouter;
  brouterProxyCfg = config.myConfig.development.brouterProxy;
  opencodeCfg = config.myConfig.development.opencode;

  brouterPiModels = import ../../lib/brouter-pi-models.nix { inherit lib; };
  agentPermissions = import ../../lib/agent-permissions.nix { inherit lib myLib; };

  # Auto-discover provider profiles from configs/pi/providers/
  # Provider descriptors come from two sources:
  #   - JSON files in configs/pi/providers/   (public, in-repo)
  #   - inline `extraProviders` attrs        (typically defined in encrypted
  #                                            host home.nix files)
  # Both produce a pi-<name> wrapper and (when baseUrl is set) a models.json
  # entry. On name collisions the inline option wins.
  providersDir = ../../../configs/pi/providers;
  allProviderFiles = builtins.attrNames (builtins.readDir providersDir);
  jsonProviderFiles = builtins.filter (f: hasSuffix ".json" f) allProviderFiles;
  jsonProviderNames = map (f: removeSuffix ".json" f) jsonProviderFiles;
  jsonProviderDescriptors = listToAttrs (
    map (n: {
      name = n;
      value = builtins.fromJSON (builtins.readFile (providersDir + "/${n}.json"));
    }) jsonProviderNames
  );

  providerDescriptors = jsonProviderDescriptors // cfg.extraProviders;
  providerNames = builtins.attrNames providerDescriptors;

  # Build shell function bodies for pi-<name> wrappers. Each wrapper pins a
  # provider + model (and optionally thinking level) by forwarding to `pi`
  # with the appropriate CLI flags.
  #
  # The descriptor's optional `sshenv` block has two modes:
  #
  #   1. auth.json mode (default when sshenv is set):
  #      Routes auth through the sshenv-auth extension (see
  #      configs/pi/extensions/sshenv-auth/) by:
  #        - pointing PI_CODING_AGENT_DIR at ~/.pi/<agentSubdir>/agent
  #        - symlinking shared static config from ~/.pi/agent/
  #        - exporting PI_SSHENV_PROFILE / PI_SSHENV_API_KEYS_JSON / PI_SSHENV_OAUTH_KEYS_JSON
  #      The extension reads creds from the named sshenv profile at
  #      session_start and round-trips refreshed OAuth blobs back to it.
  #
  #   2. envOnly mode (sshenv.envOnly = true):
  #      Wraps `pi` in `sshenv run <profile> --` so the profile's env vars
  #      reach pi's process unchanged. Useful for providers that pull creds
  #      from arbitrary env vars (AWS SDK chain, Vertex AI ADC, etc.) rather
  #      than auth.json. No per-profile agent dir, no extension activation.
  mkWrapper =
    name:
    let
      descriptor = providerDescriptors.${name};
      thinkingFlag =
        if descriptor ? thinking then " --thinking ${escapeShellArg descriptor.thinking}" else "";
      hasSshenv = descriptor ? sshenv;
      sshenvSpec = descriptor.sshenv or { };
      sshenvEnvOnly = sshenvSpec.envOnly or false;
      sshenvProfile = sshenvSpec.profile or name;
      sshenvAgentSubdir = sshenvSpec.agentSubdir or sshenvProfile;
      sshenvApiKeysJson = builtins.toJSON (sshenvSpec.apiKeys or { });
      sshenvOAuthJson = builtins.toJSON (sshenvSpec.oauth or { });
      sshenvAgentDir = "${config.home.homeDirectory}/.pi/${sshenvAgentSubdir}/agent";
      sharedAgentDir = "${config.home.homeDirectory}/.pi/agent";
      apiKeyFlag =
        if descriptor ? apiKeyEnv && !hasSshenv then " --api-key \"$" + descriptor.apiKeyEnv + "\"" else "";
    in
    if hasSshenv && sshenvEnvOnly then
      ''
        exec ${pkgs.sshenv}/bin/sshenv run ${escapeShellArg sshenvProfile} -- pi --provider ${escapeShellArg descriptor.provider} --model ${escapeShellArg descriptor.model}${thinkingFlag} "$@"
      ''
    else if hasSshenv then
      ''
        _agent_dir=${escapeShellArg sshenvAgentDir}
        _shared=${escapeShellArg sharedAgentDir}
        mkdir -p "$_agent_dir/sessions"
        chmod 700 "$_agent_dir" 2>/dev/null || true
        for _f in settings.json models.json keybindings.json agent-permissions.json SYSTEM.md APPEND_SYSTEM.md; do
          if [ -e "$_shared/$_f" ]; then
            ln -sfn "$_shared/$_f" "$_agent_dir/$_f"
          fi
        done
        for _f in extensions skills agent-skills prompts themes npm bun tools git; do
          if [ -e "$_shared/$_f" ]; then
            ln -sfn "$_shared/$_f" "$_agent_dir/$_f"
          fi
        done
        if [ "''${PI_SSHENV_LOCK:-0}" = "1" ]; then
          exec 9>"$_agent_dir/.sshenv.lock"
          if ! ${pkgs.flock}/bin/flock -n 9; then
            echo "pi-${name}: another instance is running, waiting for it to exit..." >&2
            ${pkgs.flock}/bin/flock 9
          fi
        fi
        PI_CODING_AGENT_DIR="$_agent_dir" \
        PI_SSHENV_PROFILE=${escapeShellArg sshenvProfile} \
        PI_SSHENV_API_KEYS_JSON=${escapeShellArg sshenvApiKeysJson} \
        PI_SSHENV_OAUTH_KEYS_JSON=${escapeShellArg sshenvOAuthJson} \
          pi --provider ${escapeShellArg descriptor.provider} --model ${escapeShellArg descriptor.model}${thinkingFlag} "$@"
      ''
    else
      ''
        pi --provider ${escapeShellArg descriptor.provider} --model ${escapeShellArg descriptor.model}${apiKeyFlag}${thinkingFlag} "$@"
      '';

  providerWrapperCommands = builtins.listToAttrs (
    map (name: {
      name = "pi-${name}";
      value = mkWrapper name;
    }) providerNames
  );

  # Auto-discover provider models from provider descriptors.
  # Each descriptor can optionally define baseUrl, apiKey, and models to
  # register it in Pi's model registry.
  mkProviderModelsEntry =
    name:
    let
      descriptor = providerDescriptors.${name};
      hasModels = descriptor ? models && descriptor.models != [ ];
    in
    if descriptor ? baseUrl then
      {
        providers.${name} = {
          baseUrl = descriptor.baseUrl;
          api = descriptor.api or "openai-completions";
          apiKey = descriptor.apiKey or "";
          compat = descriptor.compat or { };
          models =
            if hasModels then
              descriptor.models
            else
              [
                {
                  id = lib.last (lib.splitString "/" descriptor.model);
                  name = lib.last (lib.splitString "/" descriptor.model);
                  reasoning = descriptor.reasoning or false;
                  thinkingLevelMap =
                    descriptor.thinkingLevelMap or {
                      off = "none";
                      minimal = "minimal";
                      low = "low";
                      medium = "medium";
                      high = "high";
                      xhigh = "max";
                    };
                  input = [ "text" ];
                  contextWindow = descriptor.contextWindow or 131072;
                  maxTokens = descriptor.maxTokens or 8192;
                }
              ];
        };
      }
    else
      { };
  discoveredProviderModels = map mkProviderModelsEntry providerNames;

  # Reuse shared agent permission files so Pi follows the same plan/build rules.
  permissionsDir = ../../../configs/agents/permissions;

  basePermissionConfig = {
    agent = {
      build = {
        tools = {
          write = true;
          edit = true;
          bash = true;
        };
        permission = {
          bash = {
            "*" = "allow";
          };
          external_directory = "allow";
        };
      };
      plan = {
        tools = {
          write = false;
          edit = false;
          bash = true;
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
    inherit basePermissionConfig;
    overrides = agentsCfg.permissions.overrides ++ opencodeCfg.overrides ++ cfg.permissionOverrides;
  };

  # Auto-discover skill directories from configs/pi/skills/
  skillsDir = ../../../configs/pi/skills;
  skillEntries =
    if builtins.pathExists skillsDir then builtins.attrNames (builtins.readDir skillsDir) else [ ];
  isSkillDir =
    name:
    let
      full = skillsDir + "/${name}";
      isDir = (builtins.readDir skillsDir).${name} or null == "directory";
    in
    isDir && builtins.pathExists full && builtins.hasAttr "SKILL.md" (builtins.readDir full);
  skillNames = builtins.filter isSkillDir skillEntries;

  # Reuse the shared agent skill set for Pi. Keep it in a separate resource root
  # so Pi-native skills in ~/.pi/agent/skills/ can coexist and override by name.
  # The whole tree is copied so relative references like ../_shared/*.md keep working.
  sharedAgentSkillsDir = ../../../configs/agents/skills;
  sharedAgentSkillsForPi = pkgs.runCommand "pi-shared-agent-skills" { } ''
        mkdir -p "$out"
        cp -R ${sharedAgentSkillsDir}/. "$out/"
        rm -rf "$out/tone-clone"
        cp -R ${inputs.tone-clone-src}/skills/tone-clone "$out/tone-clone"
        chmod -R u+w "$out"

        find "$out" -name SKILL.md -type f | while IFS= read -r skill; do
          if grep -Eq 'Question(\(\*\)| tool)|Task(\(\*\)| tool)|Glob\(\*\)|Grep\(\*)' "$skill"; then
            cat >> "$skill" <<'EOF'

    ## Pi Compatibility

    This skill was authored for OpenCode. In Pi:

    - Use the `question` tool from `@rwese/pi-question` for OpenCode `Question(*)`.
      - Put prompts under `questions: [{ questionTopic, prompt, type, options }]`.
      - Keep `prompt` short (about 1-3 lines). The question UI truncates long prompts.
      - If approval context, diffs, plans, findings, or trade-offs are long, write them as normal assistant text before calling `question`, then make `prompt` refer to the context above.
      - Keep `questionTopic`, option labels, and descriptions concise; do not use them as long-form context containers.
      - Use `type: "single"` for single-choice questions and `type: "multi"` for multi-select questions.
      - Translate each option to `{ value, label, description?, recommended? }`.
      - Use `recommended: true` for pre-selected or recommended options.
      - Treat the `question` tool result as the direct user approval artifact required by this skill.

    - Use the `subagent` tool from `pi-subagents` for OpenCode `Task(*)`.
      - For exploration/search tasks, prefer agent `scout`.
      - For planning tasks, prefer agent `planner`.
      - For implementation tasks, prefer agent `worker`.
      - For review tasks, prefer agent `reviewer`.

    - Use Pi's `find` tool for OpenCode `Glob(*)`.
    - Use Pi's `grep` tool for OpenCode `Grep(*)`.
    EOF
          fi
        done
  '';

  # Third-party Pi packages. Pin npm versions here so the Nix-managed
  # settings file is the source of truth.
  piPackageSources = [
    "npm:@rwese/pi-question@2.2.0"
    "npm:pi-subagents@0.20.1"
    {
      source = "npm:pi-figma-mcp@0.1.2";
      # Keep the Figma MCP extension installed, but do not load its skill into
      # every session. The local zz-figma-tool-gate extension exposes /figma-on
      # and keeps figma_* tools inactive until explicitly enabled.
      skills = [ ];
    }
  ];

  # Nix-provided npm defaults to a read-only Nix store global prefix. Point Pi's
  # package installer at a user-writable prefix instead.
  piNpmPrefix = "${config.home.homeDirectory}/.pi/agent/npm";

  # Auto-discover prompt template files from configs/pi/prompts/
  promptsDir = ../../../configs/pi/prompts;
  promptEntries =
    if builtins.pathExists promptsDir then builtins.attrNames (builtins.readDir promptsDir) else [ ];
  promptFiles = builtins.filter (f: hasSuffix ".md" f) promptEntries;

  # Auto-discover theme files from configs/pi/themes/
  themesDir = ../../../configs/pi/themes;
  themeEntries =
    if builtins.pathExists themesDir then builtins.attrNames (builtins.readDir themesDir) else [ ];
  themeFiles = builtins.filter (f: hasSuffix ".json" f) themeEntries;

  # Auto-discover extension files/directories from configs/pi/extensions/
  extensionsDir = ../../../configs/pi/extensions;
  extensionEntries =
    if builtins.pathExists extensionsDir then
      builtins.attrNames (builtins.readDir extensionsDir)
    else
      [ ];
  isExtensionEntry =
    name:
    let
      kind = (builtins.readDir extensionsDir).${name} or null;
      full = extensionsDir + "/${name}";
    in
    (kind == "regular" && (hasSuffix ".ts" name || hasSuffix ".js" name))
    || (kind == "directory" && builtins.pathExists (full + "/index.ts"));
  extensionNames = builtins.filter isExtensionEntry extensionEntries;

  # Read and parse host-specific settings overrides
  overrideConfigs = map (f: builtins.fromJSON (builtins.readFile f)) cfg.overrides;

  # Ollama provider config (only when ollama is enabled)
  ollamaCfg = config.myConfig.tools.ai.ollama;
  ollamaModels = unique ([ ollamaCfg.model ] ++ ollamaCfg.extraModels);
  mkOllamaModelEntry = model: {
    id = model;
    name = model;
    reasoning = false;
    input = [ "text" ];
    contextWindow = 131072;
    maxTokens = 8192;
    cost = {
      input = 0;
      output = 0;
      cacheRead = 0;
      cacheWrite = 0;
    };
  };

  # Base models.json merged with conditional local providers
  baseModelsConfig = builtins.fromJSON (builtins.readFile ../../../configs/pi/models.json);
  ollamaModelsEntry = {
    baseUrl = ollamaCfg.serverUrl;
    api = "openai-completions";
    apiKey = "ollama";
    models = map mkOllamaModelEntry ollamaModels;
  };
  brouterModelsEntry = brouterPiModels.mkProvider {
    baseUrl = "http://${brouterCfg.host}:${toString brouterCfg.port}/v1";
  };
  brouterProxyModelsEntry = brouterPiModels.mkProvider {
    baseUrl = "http://${brouterProxyCfg.host}:${toString brouterProxyCfg.port}/v1";
    nameSuffix = " (proxy)";
  };
  brouterDefaultEnabledModels = map (m: m.id) brouterPiModels.defaultModelDefs;

  mergedModelsConfig = foldl' myLib.deepMerge baseModelsConfig (
    (optional ollamaCfg.enable { providers.ollama = ollamaModelsEntry; })
    ++ (optional (brouterCfg.enable && brouterCfg.enablePiIntegration) {
      providers.${brouterCfg.providerName} = brouterModelsEntry;
    })
    ++ (optional (brouterProxyCfg.enable && brouterProxyCfg.enablePiIntegration) {
      providers.${brouterProxyCfg.providerName} = brouterProxyModelsEntry;
    })
    ++ discoveredProviderModels
  );

  # Base settings.json + module-derived keys + extraSettings + overrides
  baseSettings = builtins.fromJSON (builtins.readFile ../../../configs/pi/settings.json);
  keybindingsConfig = ../../../configs/pi/keybindings.json;

  derivedSettings = {
    enableInstallTelemetry = false;
  }
  // (optionalAttrs (cfg.models != [ ]) {
    models = cfg.models;
    enabledModels = cfg.models;
  })
  // (optionalAttrs (brouterCfg.enable && brouterCfg.enablePiIntegration && brouterCfg.makePiDefault)
    {
      defaultProvider = brouterCfg.providerName;
      defaultModel = brouterCfg.defaultModel;
      enabledModels = brouterDefaultEnabledModels;
    }
  )
  // (optionalAttrs
    (brouterProxyCfg.enable && brouterProxyCfg.enablePiIntegration && brouterProxyCfg.makePiDefault)
    {
      defaultProvider = brouterProxyCfg.providerName;
      defaultModel = brouterProxyCfg.defaultModel;
      enabledModels = brouterDefaultEnabledModels;
    }
  );

  mergedSettingsBase = foldl' myLib.deepMerge baseSettings (
    [
      derivedSettings
      cfg.extraSettings
    ]
    ++ overrideConfigs
  );

  mergedSettings = mergedSettingsBase // {
    # settings.json paths resolve relative to ~/.pi/agent, where this module
    # deploys the generated shared agent skill root below. Add this after
    # overrides so host-local skill settings don't accidentally drop shared skills.
    skills = unique ((mergedSettingsBase.skills or [ ]) ++ [ "agent-skills" ]);

    # Load Pi-native packages that provide structured questions and subagent
    # delegation for imported shared skills.
    packages = unique ((mergedSettingsBase.packages or [ ]) ++ piPackageSources);

    npmCommand =
      mergedSettingsBase.npmCommand or [
        "npm"
        "--prefix"
        piNpmPrefix
      ];
  };
in
{
  options.myConfig.development.pi = {
    enable = mkEnableOption "Pi coding agent CLI";

    models = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "claude-*"
        "gpt-5*"
      ];
      description = "Model patterns for Ctrl+P cycling (settings.json `models` field)";
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra keys deep-merged into settings.json after base + derived keys";
    };

    overrides = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "JSON files deep-merged into settings.json last (e.g., host-specific encrypted overrides)";
    };

    permissionOverrides = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Additional Pi-only shared-agent permission JSON files merged after shared and OpenCode config overrides.";
    };

    extraProviders = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      example = literalExpression ''
        {
          openai-nds = {
            provider = "openai-codex";
            model = "gpt-5.5-fast";
            thinking = "high";
            sshenv = {
              profile = "openai-nds";
              agentSubdir = "openai-nds";
              oauth.openai-codex = "OPENAI_CODEX_AUTH_JSON_B64";
            };
          };
        }
      '';
      description = ''
        Inline provider descriptors merged with the JSON files in
        configs/pi/providers/. Each entry produces a pi-<name> wrapper. Use
        this from encrypted host home.nix files to keep work-only / private
        profiles out of the public tree. Inline entries win on name
        collisions with the in-repo JSON descriptors.
      '';
    };

  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [
        pkgs.pi
        pkgs.tone-clone
      ];

      home.sessionVariables = {
        # Pi respects this env var to disable anonymous install/update telemetry.
        PI_TELEMETRY = "0";

        # Rewrite assistant replies into a more listenable script before TTS.
        PI_READ_REPLY_AUDIO_ADAPTER = "llm";
        PI_READ_REPLY_AUDIO_ADAPTER_PROVIDER = "openai";
        PI_READ_REPLY_AUDIO_ADAPTER_MODEL = "gpt-4o-mini";
      };

      # Deploy the merged settings.json to pi's default config location (~/.pi/agent/).
      home.file.".pi/agent/settings.json".text = builtins.toJSON mergedSettings;

      # Register custom provider models that Pi's built-in registry may not know yet.
      home.file.".pi/agent/models.json".text = builtins.toJSON mergedModelsConfig;

      # Free Tab for the agent-modes shortcut; Ctrl+Space keeps autocomplete available.
      home.file.".pi/agent/keybindings.json".source = keybindingsConfig;

      # Shared agent permission config consumed by the local Pi extension.
      home.file.".pi/agent/agent-permissions.json".text = builtins.toJSON mergedPermissions;

      # Shared agent skills made available to Pi via settings.json `skills`.
      home.file.".pi/agent/agent-skills".source = sharedAgentSkillsForPi;

      # User-writable npm prefix for Pi package installs under Nix.
      home.file.".pi/agent/npm/.keep".text = "";

      # Pi 0.70.6+ runs as a Bun-compiled binary and resolves global npm
      # package resources via `bun pm bin -g`, even when `npmCommand` points
      # installs at the Nix-managed npm prefix above. Give Pi a private Bun
      # global tree that maps back to the real npm-managed node_modules.
      home.activation.setupPiBunGlobal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        bun_global="${config.home.homeDirectory}/.pi/agent/bun/install/global"
        bun_bin="${config.home.homeDirectory}/.pi/agent/bun/bin"
        npm_node_modules="${piNpmPrefix}/lib/node_modules"

        mkdir -p "$bun_global" "$bun_bin" "$npm_node_modules"

        if [ ! -f "$bun_global/package.json" ]; then
          printf '%s\n' '{"name":"pi-bun-global","private":true}' > "$bun_global/package.json"
        fi

        if [ -e "$bun_global/node_modules" ] && [ ! -L "$bun_global/node_modules" ]; then
          rm -rf "$bun_global/node_modules"
        fi
        ln -sfn "$npm_node_modules" "$bun_global/node_modules"
      '';
    }

    # Cross-shell wrapper commands for per-provider profile selection (pi-bedrock, pi-codex, ...)
    {
      homeModules.shell.shared.functions = providerWrapperCommands;
    }

    # Conditional Ollama wrapper (only when tools.ai.ollama is enabled)
    (mkIf ollamaCfg.enable {
      homeModules.shell.shared.functions.pi-ollama = ''
        pi --provider ollama --model ${escapeShellArg ollamaCfg.model} "$@"
      '';
    })

    # Conditional brouter wrapper. The provider itself is registered in models.json above.
    (mkIf (brouterCfg.enable && brouterCfg.enablePiIntegration) {
      homeModules.shell.shared.functions.pi-brouter = ''
        pi --provider ${escapeShellArg brouterCfg.providerName} --model ${escapeShellArg brouterCfg.defaultModel} "$@"
      '';
    })

    # Conditional brouter-proxy wrapper. The provider is registered in models.json above.
    (mkIf (brouterProxyCfg.enable && brouterProxyCfg.enablePiIntegration) {
      homeModules.shell.shared.functions.pi-brouter-proxy = ''
        pi --provider ${escapeShellArg brouterProxyCfg.providerName} --model ${escapeShellArg brouterProxyCfg.defaultModel} "$@"
      '';
    })

    # Auto-deploy skill directories from configs/pi/skills/<name>/
    (mkIf (skillNames != [ ]) {
      home.file = builtins.listToAttrs (
        map (name: {
          name = ".pi/agent/skills/${name}";
          value = {
            source = skillsDir + "/${name}";
            recursive = true;
          };
        }) skillNames
      );
    })

    # Auto-deploy prompt templates from configs/pi/prompts/*.md
    (mkIf (promptFiles != [ ]) {
      home.file = builtins.listToAttrs (
        map (fname: {
          name = ".pi/agent/prompts/${fname}";
          value = {
            source = promptsDir + "/${fname}";
          };
        }) promptFiles
      );
    })

    # Auto-deploy theme files from configs/pi/themes/*.json
    (mkIf (themeFiles != [ ]) {
      home.file = builtins.listToAttrs (
        map (fname: {
          name = ".pi/agent/themes/${fname}";
          value = {
            source = themesDir + "/${fname}";
          };
        }) themeFiles
      );
    })

    # Auto-deploy Pi extensions from configs/pi/extensions/.
    (mkIf (extensionNames != [ ]) {
      home.file = builtins.listToAttrs (
        map (name: {
          name = ".pi/agent/extensions/${name}";
          value = {
            source = extensionsDir + "/${name}";
            recursive = true;
          };
        }) extensionNames
      );
    })
  ]);
}
