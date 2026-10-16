{ lib }:
let
  p = import ../agent-permissions.nix { inherit lib; };
  cfg = {
    autoDiscover = true;
    include = [ ];
    exclude = [ ];
    yolo = [ ];
    restricted = [ ];
  };
  merged =
    c:
    p.mkPermissions {
      permissionsDir = ../../../configs/agents/permissions;
      cfg = c;
    };
  hash = x: builtins.hashString "sha256" (builtins.toJSON x);
  fragment = permission: { agent.plan = { inherit permission; }; };
  permission = x: x.agent.plan.permission;
  fails = x: !(builtins.tryEval (builtins.deepSeq x true)).success;
  layerA = {
    command = {
      "git *" = "deny";
    };
    command_patterns = {
      "git status" = "allow";
    };
  };
  layerB = {
    command_patterns = {
      "git status" = "allow";
    };
  };
  policy =
    layers:
    fragment {
      command_policy = {
        version = 1;
        inherit layers;
      };
    };
  compose = inputs: p.compose { inherit inputs; };
  fallbacks = {
    opencode.bash."*" = "deny";
    pi.bash."*" = "ask";
  };
  ordered = compose [
    (fragment { command."*" = "ask"; })
    (policy [ layerA ])
    (policy [
      layerB
      layerA
    ])
  ];
  advancedPatterns = [
    "git [--no-pager|--paginate] status ..."
    "tool [literal group]* <arg> /abc/imsx <options>* ..."
    "tool /a.*/i"
    "tool /secret/"
    "tool /abc/imsx"
    "tool <arg>"
    "tool <options>*"
    "tool [a]*"
  ];
  tests = {
    shippedVariantsStayLegacy =
      builtins.all
        (
          variant:
          builtins.all (
            agent: !(agent.permission or { } ? command_policy) && !(agent.permission or { } ? compatibility)
          ) (builtins.attrValues (merged variant).agent)
        )
        [
          cfg
          (
            cfg
            // {
              restricted = [
                "git"
                "brew"
              ];
            }
          )
          (
            cfg
            // {
              yolo = [
                "git"
                "brew"
              ];
            }
          )
        ];
    yoloVariantsProjectBothTargets =
      let
        permissions = merged (
          cfg
          // {
            yolo = [
              "git"
              "brew"
            ];
          }
        );
      in
      p.forLegacyTarget "opencode" permissions == p.forLegacyTarget "pi" permissions;
    explicitIncludeAndOverrideOrder =
      let
        result = p.mkPermissions {
          permissionsDir = ./fixtures/permissions;
          cfg = cfg // {
            autoDiscover = false;
            include = [
              "b"
              "a"
            ];
          };
          overrides = [ ./fixtures/permissions/b.json ];
        };
      in
      (permission result).command_policy.layers == [
        { command."tool *" = "allow"; }
        { command."tool *" = "deny"; }
        { command."tool *" = "allow"; }
      ];
    discoveryOrder =
      (permission (
        p.mkPermissions {
          permissionsDir = ./fixtures/permissions;
          inherit cfg;
        }
      )).command_policy.layers == [
        { command."tool *" = "deny"; }
        { command."tool *" = "allow"; }
      ];
    actualOverrideConflictFails = fails (
      p.mkPermissions {
        permissionsDir = ../../../configs/agents/permissions;
        cfg = cfg // {
          autoDiscover = false;
          include = [ "git" ];
        };
        overrides = [ ./fixtures/conflict.json ];
      }
    );
    policyNotMapFails = fails (
      p.forBcode (fragment {
        command_policy = [ ];
      })
    );
    layersNotListFails = fails (
      p.forBcode (fragment {
        command_policy = {
          version = 1;
          layers = { };
        };
      })
    );
    unknownPolicyFieldsFail = fails (
      p.forBcode (fragment {
        command_policy = {
          version = 1;
          layers = [ ];
          extra = true;
        };
      })
    );
    openCodeBaseMergeUnchanged =
      let
        base = builtins.fromJSON (builtins.readFile ../../../configs/opencode/opencode.json);
      in
      p.forLegacyTarget "opencode" (lib.recursiveUpdate base (merged cfg))
      == lib.recursiveUpdate base (p.forLegacy (merged cfg));
    openCodeFallbackReplacesBaseDefaults =
      let
        base = builtins.fromJSON (builtins.readFile ../../../configs/opencode/opencode.json);
      in
      (permission (
        p.forLegacyTarget "opencode" (
          lib.recursiveUpdate base (fragment {
            command_policy = {
              version = 1;
              layers = [ layerA ];
            };
            compatibility = fallbacks;
          })
        )
      )).bash == {
        "*" = "deny";
      };
    oldBcodeOutput =
      hash (p.forBcode (merged cfg))
      == "4e8c059f0b160b511fdc4549899811641b58d9767ac2cbcf1890eb3c6a68e0c6";
    oldOpenCodeOutput =
      hash (p.forLegacyTarget "opencode" (merged cfg))
      == "a76f5f87dbe6cd341bb581f09bd9d4b97288a2b735d4424119989169cad52871";
    oldPiOutput =
      hash (p.forLegacyTarget "pi" (merged cfg))
      == "a76f5f87dbe6cd341bb581f09bd9d4b97288a2b735d4424119989169cad52871";
    restrictedOptionalNoPagerPreserved =
      hash (
        p.forLegacy (
          merged (
            cfg
            // {
              restricted = [
                "git"
                "brew"
              ];
            }
          )
        )
      ) == "b00179c5d31f40b86f5d456091fcbb001df76185a06f66f507bfc41c971bb4e7";
    layersAppendNotMergeSortOrDeduplicate =
      (permission ordered).command_policy.layers == [
        layerA
        layerB
        layerA
      ];
    implicitBaseRetained = (permission ordered).command."*" == "ask";
    bcodeLayersUnchanged = p.forBcode ordered == ordered;
    baseIsOverridableDefault =
      (permission (
        p.compose {
          base = fragment { command."git *" = "deny"; };
          inputs = [ (fragment { command."git *" = "ask"; }) ];
        }
      )).command."git *" == "ask";
    identicalRulesAllowed =
      compose [
        (fragment { command.x = "deny"; })
        (fragment { command.x = "deny"; })
      ] == fragment { command.x = "deny"; };
    commandConflictFails = fails (compose [
      (fragment { command.x = "deny"; })
      (fragment { command.x = "allow"; })
    ]);
    aliasConflictFails = fails (compose [
      (fragment {
        bash.x = "deny";
        command.x = "allow";
      })
    ]);
    crossInputAliasConflictFails = fails (compose [
      (fragment { bash.x = "deny"; })
      (fragment { command.x = "allow"; })
    ]);
    patternConflictFails = fails (compose [
      (fragment { command_patterns.x = "deny"; })
      (fragment { command_patterns.x = "allow"; })
    ]);
    fallbackConflictFails = fails (compose [
      (fragment { compatibility = fallbacks; })
      (fragment { compatibility.pi.bash."*" = "deny"; })
    ]);
    invalidVersionFails = fails (
      p.forBcode (fragment {
        command_policy = {
          version = 2;
          layers = [ ];
        };
      })
    );
    unknownLayerFieldsFail = fails (p.forBcode (policy [ { bash.x = "deny"; } ]));
    invalidActionFails = fails (
      p.forBcode (fragment {
        command_patterns.x = "oops";
      })
    );
    orderedNeedsFallbackBothTargets = builtins.all (target: fails (p.forLegacyTarget target ordered)) [
      "opencode"
      "pi"
    ];
    evenEmptyPolicyIsOptIn = fails (p.forLegacy (policy [ ]));
    advancedFailsClosed = builtins.all (
      pattern:
      builtins.all
        (
          target:
          fails (
            p.forLegacyTarget target (fragment {
              command_patterns.${pattern} = "deny";
            })
          )
        )
        [
          "opencode"
          "pi"
        ]
    ) advancedPatterns;
    advancedBcodeStringsPreserved = builtins.all (
      pattern:
      (permission (
        p.forBcode (fragment {
          command_patterns.${pattern} = "deny";
          compatibility = fallbacks;
        })
      )) == {
        command_patterns.${pattern} = "deny";
      }
    ) advancedPatterns;
    targetFallbacksIndependent =
      builtins.all
        (
          target:
          (permission (
            p.forLegacyTarget target (fragment {
              command."*" = "allow";
              bash."tool *" = "allow";
              command_patterns."tool /secret/" = "deny";
              command_policy = {
                version = 1;
                layers = [
                  layerA
                  layerB
                ];
              };
              compatibility = fallbacks;
              external_directory = "deny";
            })
          )) == {
            bash = fallbacks.${target}.bash;
            external_directory = "deny";
          }
        )
        [
          "opencode"
          "pi"
        ];
    missingTargetFails = fails (
      p.forLegacyTarget "pi" (fragment {
        command_patterns."tool <arg>" = "deny";
        compatibility.opencode = fallbacks.opencode;
      })
    );
    incompleteFallbackFails = fails (
      p.forLegacy (fragment {
        compatibility.opencode.bash."tool *" = "deny";
      })
    );
    unknownMetadataFails = fails (
      p.forBcode (fragment {
        compatibility.bcode = fallbacks.pi;
      })
    );
    projectedConflictFails = fails (
      p.forLegacy (fragment {
        command."git status" = "allow";
        command_patterns."git [--no-pager] status ..." = "deny";
      })
    );
    literalOptionalProjection =
      (permission (
        p.forLegacy (fragment {
          command_patterns."git [--no-pager] status ..." = "allow";
        })
      )).bash == {
        "git status" = "allow";
        "git status *" = "allow";
        "git --no-pager status" = "allow";
        "git --no-pager status *" = "allow";
      };
    malformedFinitePatternFails =
      builtins.all
        (
          s:
          fails (
            p.forLegacy (fragment {
              command_patterns.${s} = "allow";
            })
          )
        )
        [
          "..."
          ""
          "tool  status"
        ];
    unknownTargetFails = fails (p.forLegacyTarget "unknown" { });
    noMetadataForNoPermission =
      p.forBcode { agent.plan.tools.x = false; } == { agent.plan.tools.x = false; };
  };
  failed = builtins.attrNames (lib.filterAttrs (_: ok: !ok) tests);
in
assert lib.assertMsg (failed == [ ]) "Failed permission tests: ${lib.concatStringsSep ", " failed}";
{
  passed = builtins.length (builtins.attrNames tests);
  inherit tests;
}
