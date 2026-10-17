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
    else if permission ? compatibility then
      fail "compatibility tables are no longer supported; use shared command_patterns"
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
            fail "conflicting ${context} rule ${builtins.toJSON key}; use an explicit ordered layer (legacy targets cannot represent arbitrary ordered policies)"
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
              };
          }
        )
      ) right.agent;
    };

  # Parse once and lower automatically; target runtimes still own glob matching.
  compiler = import ./permission-compiler.nix { inherit lib; };
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
      mapPermissions (
        raw:
        let
          permission = validatePermission raw;
          rules = lib.concatLists (
            lib.mapAttrsToList (compiler.compile target) (permission.command_patterns or { })
          );
          bash = lib.foldl' (
            result: rule:
            if result ? ${rule.name} && result.${rule.name} != rule.value then
              fail "${target}: conflicting projected bash rule ${builtins.toJSON rule.name}"
            else
              result // { ${rule.name} = rule.value; }
          ) ((permission.bash or { }) // (permission.command or { })) rules;
        in
        if permission ? command_policy then
          fail "${target}: ordered command_policy is not representable by raw globs; keep shared policies order-independent"
        else
          removeAttrs permission [
            "command"
            "command_patterns"
          ]
          // lib.optionalAttrs (permission ? command || permission ? command_patterns) { inherit bash; }
      ) permissions;
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

  forBcode = permissions: mapPermissions validatePermission permissions;
  inherit forLegacyTarget;
  legacyJSON = compiler.toJSON;
  forLegacy = forLegacyTarget "opencode";
}
