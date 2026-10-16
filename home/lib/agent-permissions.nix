{ lib }:

let
  fail = message: throw "Shared agent permissions: ${message}";
  actions = [
    "allow"
    "ask"
    "deny"
  ];
  ruleMap =
    value:
    builtins.isAttrs value
    && builtins.all (name: name != "" && builtins.elem value.${name} actions) (
      builtins.attrNames value
    );
  only =
    keys: value:
    builtins.isAttrs value && builtins.all (key: builtins.elem key keys) (builtins.attrNames value);
  validLayer =
    layer:
    only [ "command" "command_patterns" ] layer
    && ruleMap (layer.command or { })
    && ruleMap (layer.command_patterns or { });
  validPolicy =
    policy:
    only [ "version" "layers" ] policy
    && (policy.version or null) == 1
    && builtins.isList (policy.layers or null)
    && builtins.all validLayer policy.layers;
  validCompatibility =
    value:
    only [ "opencode" "pi" ] value
    && builtins.all (
      target:
      only [ "bash" ] value.${target}
      && value.${target} ? bash
      && ruleMap value.${target}.bash
      && value.${target}.bash ? "*"
    ) (builtins.attrNames value);
  validatePermission =
    permission:
    if
      !(builtins.all (key: ruleMap (permission.${key} or { })) [
        "bash"
        "command"
        "command_patterns"
      ])
    then
      fail "command maps must contain nonempty patterns and allow/ask/deny actions"
    else if permission ? command_policy && !(validPolicy permission.command_policy) then
      fail "command_policy must be { version = 1; layers = [ { command = {...}; command_patterns = {...}; } ... ]; }"
    else if permission ? compatibility && !(validCompatibility permission.compatibility) then
      fail "compatibility must contain explicit opencode/pi { bash = { \"*\" = action; ... }; } complete replacements"
    else
      permission;
  mapPermissions =
    f: config:
    config
    // lib.optionalAttrs (config ? agent) {
      agent = lib.mapAttrs (
        _: agent:
        agent
        // lib.optionalAttrs (agent ? permission) {
          permission = f agent.permission;
        }
      ) config.agent;
    };
  validate = mapPermissions validatePermission;
  mergePermission =
    left: right:
    let
      merged = lib.recursiveUpdate left right;
      policies = builtins.filter (p: p != null) [
        (left.command_policy or null)
        (right.command_policy or null)
      ];
    in
    merged
    // lib.optionalAttrs (policies != [ ]) {
      command_policy = {
        version = 1;
        layers = lib.concatMap (p: p.layers) policies;
      };
    };
  merge =
    left: right:
    let
      merged = lib.recursiveUpdate left right;
    in
    merged
    // lib.optionalAttrs (merged ? agent) {
      agent = lib.mapAttrs (
        name: agent:
        agent
        // lib.optionalAttrs (agent ? permission) {
          permission = mergePermission (left.agent.${name}.permission or { }) (
            right.agent.${name}.permission or { }
          );
        }
      ) merged.agent;
    };
  # Defaults may be overridden. User fragments may not silently replace a rule;
  # intentional precedence changes belong in distinct ordered policy layers.
  checkConflicts =
    left: right:
    let
      checkMap =
        context: a: b:
        lib.mapAttrs (
          key: value:
          if builtins.hasAttr key a && a.${key} != value then
            fail "conflicting ${context} rule ${builtins.toJSON key}; use an explicit ordered layer (and legacy fallbacks)"
          else
            value
        ) b;
      checked = mapPermissions (p: p) right;
    in
    checked
    // lib.optionalAttrs (right ? agent) {
      agent = lib.mapAttrs (
        name: agent:
        let
          a = left.agent.${name}.permission or { };
          b = agent.permission or { };
          aliases = checkMap "${name} command/bash" (b.bash or { }) (b.command or { });
          commands = checkMap "${name} command/bash" ((a.bash or { }) // (a.command or { })) (
            (b.command or { }) // (b.bash or { })
          );
        in
        builtins.deepSeq [ aliases commands ] (
          agent
          // lib.optionalAttrs (agent ? permission) {
            permission =
              b
              // lib.optionalAttrs (b ? command_patterns) {
                command_patterns = checkMap "${name} command_patterns" (a.command_patterns or { }) (
                  b.command_patterns or { }
                );
              }
              // lib.optionalAttrs (b ? compatibility) {
                compatibility = checkMap "${name} compatibility target" (a.compatibility or { }) b.compatibility;
              };
          }
        )
      ) right.agent;
    };

  # Only the historical finite literal subset can be expanded to text globs.
  expand =
    pattern: action:
    let
      words = lib.splitString " " pattern;
      validWord =
        word:
        builtins.match "[-A-Za-z0-9_./:=+@,%~]+" word != null
        && builtins.match "/.*/[A-Za-z]*" word == null;
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
      valid =
        pattern != ""
        && builtins.stringLength pattern <= 1024
        && builtins.length words <= 32
        && body != [ ]
        && builtins.length (builtins.filter (w: optionalWord w != null) body) <= 8
        && builtins.all (w: validWord w || optionalWord w != null) body
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
      names = lib.concatMap (
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
      fail "cannot project command pattern ${builtins.toJSON pattern}; supply permission.compatibility.<target>.bash as a complete target-compatible replacement (a stricter fallback is permitted)";

  forLegacyTarget =
    target: permissions:
    if
      !(builtins.elem target [
        "opencode"
        "pi"
      ])
    then
      fail "unknown legacy target ${target}"
    else
      permissions
      // lib.optionalAttrs (permissions ? agent) {
        agent = lib.mapAttrs (
          _: agent:
          let
            permission = validatePermission (agent.permission or { });
            fallback = permission.compatibility.${target}.bash or null;
            rules = lib.concatLists (lib.mapAttrsToList expand (permission.command_patterns or { }));
            projected = lib.foldl' (
              result: rule:
              if result ? ${rule.name} && result.${rule.name} != rule.value then
                fail "conflicting legacy bash rule ${builtins.toJSON rule.name}; supply permission.compatibility.${target}.bash"
              else
                result // { ${rule.name} = rule.value; }
            ) ((permission.bash or { }) // (permission.command or { })) rules;
            bash =
              if fallback != null then
                fallback
              else if permission ? command_policy then
                fail "${target} cannot represent ordered command_policy precedence; supply permission.compatibility.${target}.bash as a complete replacement (a stricter fallback is permitted)"
              else
                projected;
          in
          if !(agent ? permission) then
            agent
          else
            agent
            // {
              permission =
                removeAttrs permission [
                  "command"
                  "command_patterns"
                  "command_policy"
                  "compatibility"
                ]
                // lib.optionalAttrs (
                  fallback != null
                  || permission ? command
                  || permission ? command_patterns
                  || permission ? command_policy
                ) { inherit bash; };
            }
        ) permissions.agent;
      };
in
{
  # Pure composition entry point, also used by evaluation tests.
  compose =
    {
      base ? { },
      inputs ? [ ],
    }:
    let
      state =
        lib.foldl'
          (
            state: input:
            let
              checked = checkConflicts state.seen (validate input);
            in
            builtins.deepSeq checked {
              seen = merge state.seen checked;
              result = merge state.result checked;
            }
          )
          {
            seen = { };
            result = validate base;
          }
          inputs;
    in
    builtins.deepSeq state.result state.result;

  mkPermissions =
    {
      permissionsDir,
      cfg,
      basePermissionConfig ? { },
      overrides ? [ ],
    }:
    let
      allNames = map (f: lib.removeSuffix ".json" f) (
        builtins.filter (f: lib.hasSuffix ".json" f) (builtins.attrNames (builtins.readDir permissionsDir))
      );
      baseNames = builtins.filter (
        name: !(lib.hasSuffix "-restricted" name || lib.hasSuffix "-yolo" name)
      ) allNames;
      resolve =
        name:
        if builtins.elem name cfg.yolo then
          "${name}-yolo"
        else if builtins.elem name cfg.restricted then
          "${name}-restricted"
        else
          name;
      names = builtins.filter (name: !(builtins.elem name cfg.exclude)) (
        if cfg.autoDiscover then baseNames else cfg.include
      );
      # Discovery is sorted; explicit include and override lists retain caller order.
      paths = map (name: permissionsDir + "/${resolve name}.json") names ++ overrides;
      self = import ./agent-permissions.nix { inherit lib; };
    in
    self.compose {
      base = basePermissionConfig;
      inputs = map (p: builtins.fromJSON (builtins.readFile p)) paths;
    };

  forBcode =
    permissions: mapPermissions (p: removeAttrs (validatePermission p) [ "compatibility" ]) permissions;
  inherit forLegacyTarget;
  forLegacy = forLegacyTarget "opencode";
}
