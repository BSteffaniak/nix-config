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

  # Auto-discover provider profiles from configs/pi/providers/
  providersDir = ../../../configs/pi/providers;
  allProviderFiles = builtins.attrNames (builtins.readDir providersDir);
  jsonProviderFiles = builtins.filter (f: hasSuffix ".json" f) allProviderFiles;
  providerNames = map (f: removeSuffix ".json" f) jsonProviderFiles;

  # Build shell function bodies for pi-<name> wrappers. Each wrapper pins a
  # provider + model (and optionally thinking level) by forwarding to `pi`
  # with the appropriate CLI flags.
  mkWrapper =
    name:
    let
      descriptor = builtins.fromJSON (builtins.readFile (providersDir + "/${name}.json"));
      thinkingFlag =
        if descriptor ? thinking then " --thinking ${escapeShellArg descriptor.thinking}" else "";
      apiKeyFlag = if descriptor ? apiKeyEnv then " --api-key \"$" + descriptor.apiKeyEnv + "\"" else "";
    in
    ''
      pi --provider ${escapeShellArg descriptor.provider} --model ${escapeShellArg descriptor.model}${apiKeyFlag}${thinkingFlag} "$@"
    '';

  providerWrapperCommands = builtins.listToAttrs (
    map (name: {
      name = "pi-${name}";
      value = mkWrapper name;
    }) providerNames
  );

  # Reuse OpenCode permission files so Pi follows the same plan/build rules.
  permissionsDir = ../../../configs/opencode/permissions;
  allPermissionFiles = builtins.attrNames (builtins.readDir permissionsDir);
  jsonPermissionFiles = builtins.filter (f: hasSuffix ".json" f) allPermissionFiles;
  allPermissionNames = map (f: removeSuffix ".json" f) jsonPermissionFiles;

  isPermissionVariant = name: hasSuffix "-restricted" name || hasSuffix "-yolo" name;
  basePermissionNames = builtins.filter (name: !(isPermissionVariant name)) allPermissionNames;

  resolvePermissionFile =
    name:
    if builtins.elem name cfg.permissions.yolo then
      "${name}-yolo"
    else if builtins.elem name cfg.permissions.restricted then
      "${name}-restricted"
    else
      name;

  discoveredPermissionNames =
    let
      base = if cfg.permissions.autoDiscover then basePermissionNames else cfg.permissions.include;
    in
    builtins.filter (name: !(builtins.elem name cfg.permissions.exclude)) base;

  resolvedPermissionNames = map resolvePermissionFile discoveredPermissionNames;

  permissionConfigs = map (
    name: builtins.fromJSON (builtins.readFile (permissionsDir + "/${name}.json"))
  ) (builtins.sort (a: b: a < b) resolvedPermissionNames);

  permissionOverrideConfigs = map (
    f: builtins.fromJSON (builtins.readFile f)
  ) cfg.permissionOverrides;

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

  mergedPermissions = foldl' myLib.deepMerge basePermissionConfig (
    permissionConfigs ++ permissionOverrideConfigs
  );

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

  # Reuse the OpenCode skill set for Pi. Keep it in a separate resource root
  # so Pi-native skills in ~/.pi/agent/skills/ can coexist and override by name.
  # The whole tree is copied so relative references like ../_shared/*.md keep working.
  opencodeSkillsDir = ../../../configs/opencode/skills;
  opencodeSkillsForPi = pkgs.runCommand "pi-opencode-skills" { } ''
    mkdir -p "$out"
    cp -R ${opencodeSkillsDir}/. "$out/"
    rm -rf "$out/tone-clone"
    cp -R ${inputs.tone-clone-src}/skills/tone-clone "$out/tone-clone"
  '';

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

  # Base settings.json + module-derived keys + extraSettings + overrides
  baseSettings = builtins.fromJSON (builtins.readFile ../../../configs/pi/settings.json);
  modelsConfig = ../../../configs/pi/models.json;
  keybindingsConfig = ../../../configs/pi/keybindings.json;

  derivedSettings = {
    enableInstallTelemetry = false;
  }
  // (optionalAttrs (cfg.models != [ ]) { models = cfg.models; });

  mergedSettingsBase = foldl' myLib.deepMerge baseSettings (
    [
      derivedSettings
      cfg.extraSettings
    ]
    ++ overrideConfigs
  );

  mergedSettings = mergedSettingsBase // {
    # settings.json paths resolve relative to ~/.pi/agent, where this module
    # deploys the generated OpenCode-compatible skill root below. Add this after
    # overrides so host-local skill settings don't accidentally drop OpenCode skills.
    skills = unique ((mergedSettingsBase.skills or [ ]) ++ [ "opencode-skills" ]);
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
      description = "OpenCode-style permission JSON files deep-merged into Pi's permission config last";
    };

    permissions = {
      autoDiscover = mkOption {
        type = types.bool;
        default = true;
        description = "Auto-discover and merge all permission files from configs/opencode/permissions/";
      };

      include = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "When autoDiscover is false, explicitly list which permission files to include (without .json)";
      };

      exclude = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Permission files to exclude from auto-discovery (without .json)";
      };

      restricted = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Use <name>-restricted.json instead of <name>.json for these programs";
      };

      yolo = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Use <name>-yolo.json instead of <name>.json for these programs";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [
        pkgs.pi
        pkgs.tone-clone
      ];

      # Pi respects this env var to disable anonymous install/update telemetry.
      home.sessionVariables.PI_TELEMETRY = "0";

      # Deploy the merged settings.json to pi's default config location (~/.pi/agent/).
      home.file.".pi/agent/settings.json".text = builtins.toJSON mergedSettings;

      # Register custom provider models that Pi's built-in registry may not know yet.
      home.file.".pi/agent/models.json".source = modelsConfig;

      # Free Tab for the opencode-modes shortcut; Ctrl+Space keeps autocomplete available.
      home.file.".pi/agent/keybindings.json".source = keybindingsConfig;

      # OpenCode-compatible permission config consumed by the local Pi extension.
      home.file.".pi/agent/opencode-permissions.json".text = builtins.toJSON mergedPermissions;

      # OpenCode skills made available to Pi via settings.json `skills`.
      home.file.".pi/agent/opencode-skills".source = opencodeSkillsForPi;
    }

    # Cross-shell wrapper commands for per-provider profile selection (pi-bedrock, pi-codex, ...)
    {
      homeModules.shell.shared.functions = providerWrapperCommands;
    }

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
