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
  cfg = config.myConfig.development.opencode;

  # Auto-discover provider profiles from configs/opencode/providers/
  providersDir = ../../../configs/opencode/providers;
  allProviderFiles = builtins.attrNames (builtins.readDir providersDir);
  jsonProviderFiles = builtins.filter (f: hasSuffix ".json" f) allProviderFiles;
  providerNames = map (f: removeSuffix ".json" f) jsonProviderFiles;

  # Read and parse the selected provider config
  providerConfig = builtins.fromJSON (builtins.readFile (providersDir + "/${cfg.provider}.json"));

  # Auto-discover permission files from configs/opencode/permissions/
  permissionsDir = ../../../configs/opencode/permissions;
  allPermissionFiles = builtins.attrNames (builtins.readDir permissionsDir);
  jsonPermissionFiles = builtins.filter (f: hasSuffix ".json" f) allPermissionFiles;
  allNames = map (f: removeSuffix ".json" f) jsonPermissionFiles;

  # Base names are those that don't end in -restricted or -yolo
  isVariant = name: hasSuffix "-restricted" name || hasSuffix "-yolo" name;
  baseNames = builtins.filter (name: !(isVariant name)) allNames;

  # Resolve each base name to the correct variant file
  # Priority: yolo > restricted > default
  resolvePermissionFile =
    name:
    if builtins.elem name cfg.permissions.yolo then
      "${name}-yolo"
    else if builtins.elem name cfg.permissions.restricted then
      "${name}-restricted"
    else
      name;

  # Filter based on autoDiscover / include / exclude
  discoveredNames =
    let
      base = if cfg.permissions.autoDiscover then baseNames else cfg.permissions.include;
    in
    builtins.filter (name: !(builtins.elem name cfg.permissions.exclude)) base;

  # Resolve to actual file names (applying restricted/yolo variants)
  resolvedNames = map resolvePermissionFile discoveredNames;

  # Read and parse each active permission file
  permissionConfigs = map (
    name: builtins.fromJSON (builtins.readFile (permissionsDir + "/${name}.json"))
  ) (builtins.sort (a: b: a < b) resolvedNames);

  # Read and parse host-specific overrides
  overrideConfigs = map (f: builtins.fromJSON (builtins.readFile f)) cfg.overrides;

  # Auto-discover skill directories from configs/opencode/skills/
  skillsDir = ../../../configs/opencode/skills;
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

  # Merge order: base → provider → permissions (alphabetical) → host overrides (in order)
  baseConfig = builtins.fromJSON (builtins.readFile ../../../configs/opencode/opencode.json);
  mergedConfig = foldl' myLib.deepMerge baseConfig (
    [ providerConfig ] ++ permissionConfigs ++ overrideConfigs
  );
in
{
  options.myConfig.development.opencode = {
    enable = mkEnableOption "OpenCode AI assistant configuration";

    provider = mkOption {
      type = types.enum providerNames;
      default = "openai";
      description = "OpenCode provider profile to use (matches filename in configs/opencode/providers/ without .json)";
    };

    overrides = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "List of JSON files to deep-merge over the base config (e.g., host-specific encrypted overrides)";
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
        description = "Use <name>-restricted.json instead of <name>.json for these programs (denies all write ops in build agent)";
      };

      yolo = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Use <name>-yolo.json instead of <name>.json for these programs (no build agent restrictions)";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      xdg.configFile."opencode/opencode.json".text = builtins.toJSON mergedConfig;
    }

    # Auto-discover and deploy all skill directories from configs/opencode/skills/
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
      home.packages = [ pkgs.tone-clone ];
    }

    # Auto-generate slash commands for all skills (local + external)
    {
      xdg.configFile = localSkillCommands // toneCloneCommand;
    }

    # Deploy raw provider files for per-provider aliases (opencode-bedrock, opencode-copilot, etc.)
    {
      xdg.configFile = builtins.listToAttrs (
        map (name: {
          name = "opencode/providers/${name}.json";
          value = {
            source = providersDir + "/${name}.json";
          };
        }) providerNames
      );
    }
  ]);
}
