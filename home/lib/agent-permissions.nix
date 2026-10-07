{ lib }:

{
  mkPermissions =
    {
      permissionsDir,
      cfg,
      basePermissionConfig ? { },
      overrides ? [ ],
    }:
    let
      allPermissionFiles = builtins.attrNames (builtins.readDir permissionsDir);
      jsonPermissionFiles = builtins.filter (f: lib.hasSuffix ".json" f) allPermissionFiles;
      allNames = map (f: lib.removeSuffix ".json" f) jsonPermissionFiles;

      isVariant = name: lib.hasSuffix "-restricted" name || lib.hasSuffix "-yolo" name;
      baseNames = builtins.filter (name: !(isVariant name)) allNames;

      resolvePermissionFile =
        name:
        if builtins.elem name cfg.yolo then
          "${name}-yolo"
        else if builtins.elem name cfg.restricted then
          "${name}-restricted"
        else
          name;

      discoveredNames =
        let
          base = if cfg.autoDiscover then baseNames else cfg.include;
        in
        builtins.filter (name: !(builtins.elem name cfg.exclude)) base;

      resolvedNames = map resolvePermissionFile discoveredNames;

      permissionConfigs = map (
        name: builtins.fromJSON (builtins.readFile (permissionsDir + "/${name}.json"))
      ) (builtins.sort (a: b: a < b) resolvedNames);

      overrideConfigs = map (f: builtins.fromJSON (builtins.readFile f)) overrides;
    in
    lib.foldl' lib.recursiveUpdate basePermissionConfig (permissionConfigs ++ overrideConfigs);

  # Project Bcode's parsed word patterns into the legacy text-glob dialect
  # consumed by OpenCode and Pi. This projection covers literal word
  # spellings only: raw text globs cannot reproduce Bcode's parsed-word
  # behavior for quoting, assignments, dynamic words, or embedded scripts.
  forLegacy =
    permissions:
    let
      expand =
        pattern: action:
        let
          words = lib.splitString " " pattern;
          validWord = word: builtins.match "[-A-Za-z0-9_./:=+@,%~]+" word != null;
          optionalWord =
            word:
            if lib.hasPrefix "[" word && lib.hasSuffix "]" word then
              let
                inner = lib.removeSuffix "]" (lib.removePrefix "[" word);
              in
              if validWord inner then inner else null
            else
              null;
          rest = lib.last words == "...";
          body = if rest then lib.init words else words;
          optionals = builtins.filter (word: optionalWord word != null) body;
          valid =
            pattern != ""
            && builtins.stringLength pattern <= 1024
            && builtins.length words <= 32
            && builtins.length optionals <= 8
            && builtins.all (word: validWord word || optionalWord word != null) body
            && validWord (builtins.head body);
          combinations = lib.foldl' (
            prefixes: word:
            let
              optional = optionalWord word;
            in
            if optional == null then
              map (prefix: prefix ++ [ word ]) prefixes
            else
              prefixes ++ map (prefix: prefix ++ [ optional ]) prefixes
          ) [ [ ] ] body;
          names = builtins.concatMap (
            tokens:
            let
              name = lib.concatStringsSep " " tokens;
            in
            [ name ] ++ lib.optional rest "${name} *"
          ) combinations;
        in
        if valid then
          map (name: {
            inherit name;
            value = action;
          }) names
        else
          throw "Cannot project command pattern ${builtins.toJSON pattern} to legacy bash globs";

      projectAgent =
        agent:
        let
          permission = agent.permission or { };
          patterns = permission.command_patterns or { };
          bash = permission.bash or { };
          command = permission.command or { };
          rules = lib.concatLists (lib.mapAttrsToList (pattern: action: expand pattern action) patterns);
          projected = lib.foldl' (
            result: rule:
            let
              existing = result.${rule.name} or null;
            in
            if existing != null && existing != rule.value then
              throw "Conflicting legacy bash rule generated for ${builtins.toJSON rule.name}"
            else
              result // { ${rule.name} = rule.value; }
          ) (bash // command) rules;
        in
        if !(permission ? command_patterns) && !(permission ? command) then
          agent
        else
          agent
          // {
            permission =
              (removeAttrs permission [
                "command_patterns"
                "command"
              ])
              // {
                bash = projected;
              };
          };
    in
    permissions
    // lib.optionalAttrs (permissions ? agent) {
      agent = lib.mapAttrs (_: projectAgent) permissions.agent;
    };
}
