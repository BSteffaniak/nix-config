{
  config,
  lib,
  pkgs,
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
    in
    ''
      pi --provider ${escapeShellArg descriptor.provider} --model ${escapeShellArg descriptor.model}${thinkingFlag} "$@"
    '';

  providerWrapperCommands = builtins.listToAttrs (
    map (name: {
      name = "pi-${name}";
      value = mkWrapper name;
    }) providerNames
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

  # Read and parse host-specific settings overrides
  overrideConfigs = map (f: builtins.fromJSON (builtins.readFile f)) cfg.overrides;

  # Base settings.json + module-derived keys + extraSettings + overrides
  baseSettings = builtins.fromJSON (builtins.readFile ../../../configs/pi/settings.json);

  derivedSettings = {
    enableInstallTelemetry = false;
  }
  // (optionalAttrs (cfg.models != [ ]) { models = cfg.models; });

  mergedSettings = foldl' myLib.deepMerge baseSettings (
    [
      derivedSettings
      cfg.extraSettings
    ]
    ++ overrideConfigs
  );
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
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [ pkgs.pi ];

      # Pi respects this env var to disable anonymous install/update telemetry.
      home.sessionVariables.PI_TELEMETRY = "0";

      # Deploy the merged settings.json to pi's default config location (~/.pi/agent/).
      home.file.".pi/agent/settings.json".text = builtins.toJSON mergedSettings;
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
  ]);
}
