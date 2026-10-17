{ lib }:
let
  compiler = import ../permission-compiler.nix { inherit lib; };
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
    exactReportHasNoDiagnostics = (compiler.report "pi" "tool status" "allow").diagnostics == [ ];
    restrictionReportPreservesRules =
      let
        r = compiler.report "opencode" "tool <options>* remove ..." "deny";
      in
      r.rules == compiler.compile "opencode" "tool <options>* remove ..." "deny"
      && r.diagnostics == [ "conservative raw-glob restriction may deny additional commands" ];
    subsetReportPreservesRules =
      let
        r = compiler.report "pi" "tool [--plain]* status ..." "allow";
      in
      r.rules == compiler.compile "pi" "tool [--plain]* status ..." "allow"
      &&
        r.diagnostics
        == [ "emitting finite literal subset; optional dynamic/repeated forms remain ungranted" ];
    reportRejectsUnsafeAllow = fails (compiler.report "pi" "tool <arg>" "allow");
    reportRejectsUnknownBackend = fails (compiler.report "unknown" "tool status" "allow");
    shippedVariantsCompileAutomatically =
      builtins.all
        (
          variant:
          builtins.deepSeq (p.forLegacyTarget "pi" (merged variant)) (
            builtins.deepSeq (p.forLegacyTarget "opencode" (merged variant)) true
          )
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
    configuredGitOptionsPreserved =
      (p.forBcode (merged (cfg // { restricted = [ "git" ]; })))
      .agent.build.permission.command_patterns."git <options>* push ..." == "deny";
    projectedGitOptionsAreRestrictions =
      builtins.all
        (
          target:
          (p.forLegacyTarget target (merged (cfg // { restricted = [ "git" ]; })))
          .agent.build.permission.bash."*git *push*" == "deny"
        )
        [
          "pi"
          "opencode"
        ];
    unrelatedRulesSurviveCompilation =
      builtins.all
        (
          target:
          let
            x =
              (p.forLegacyTarget target (merged (cfg // { restricted = [ "git" ]; })))
              .agent.build.permission.bash;
          in
          x."sudo *" == "deny" && x."git stash list" == "allow"
        )
        [
          "pi"
          "opencode"
        ];
    planMutationsNotGranted =
      builtins.all
        (
          variant:
          let
            x = (p.forBcode (merged variant)).agent.plan.permission.bash;
          in
          !(x ? "git branch *") && !(x ? "git config *") && x."git branch --list" == "allow"
        )
        [
          cfg
          (cfg // { restricted = [ "git" ]; })
          (cfg // { yolo = [ "git" ]; })
        ];
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
    orderedFailsBothTargets = builtins.all (target: fails (p.forLegacyTarget target ordered)) [
      "opencode"
      "pi"
    ];
    evenEmptyPolicyIsOptIn = fails (p.forLegacy (policy [ ]));
    advancedBcodeStringsPreserved = builtins.all (
      pattern:
      (permission (
        p.forBcode (fragment {
          command_patterns.${pattern} = "deny";
        })
      )) == {
        command_patterns.${pattern} = "deny";
      }
    ) advancedPatterns;
    compatibilityRemoved = fails (
      p.forBcode (fragment {
        compatibility.pi.bash."*" = "deny";
      })
    );
    requiredDynamicAllowFails =
      builtins.all
        (
          pattern:
          fails (
            p.forLegacy (fragment {
              command_patterns.${pattern} = "allow";
            })
          )
        )
        [
          "tool <arg>"
          "tool <options>* status ..."
          "tool /abc/"
        ];
    finiteAlternatives =
      (permission (
        p.forLegacy (fragment {
          command_patterns."tool [a|b c] show" = "allow";
        })
      )).bash == {
        "tool show" = "allow";
        "tool a show" = "allow";
        "tool b c show" = "allow";
      };
    repeatedAllowSubset =
      (permission (
        p.forLegacy (fragment {
          command_patterns."tool [-C <arg>|--plain]* status ..." = "allow";
        })
      )).bash == {
        "tool status" = "allow";
        "tool status *" = "allow";
        "tool --plain status" = "allow";
        "tool --plain status *" = "allow";
      };
    quotedLiteral =
      (permission (
        p.forLegacy (fragment {
          command_patterns."tool 'status'" = "allow";
        })
      )).bash."tool status" == "allow";
    globLiteralFails = fails (
      p.forLegacy (fragment {
        command_patterns."tool 'x?'" = "allow";
      })
    );
    malformedPatternsFail =
      builtins.all
        (
          pattern:
          fails (
            p.forLegacy (fragment {
              command_patterns.${pattern} = "deny";
            })
          )
        )
        [
          "tool [a[b]]"
          "tool [a|]"
          "tool /x/g"
          "tool [<unknown>]"
          "tool 'unfinished"
          "tool ... extra"
        ];
    arbitraryRegexRestriction =
      (permission (
        p.forLegacy (fragment {
          command_patterns."tool /a[bc]+/ ..." = "deny";
        })
      )).bash."*tool *" == "deny";
    regexClassSlash =
      (permission (
        p.forLegacy (fragment {
          command_patterns."tool /a[/]b/ ..." = "deny";
        })
      )).bash."*tool *" == "deny";
    boundedExpansion = fails (
      p.forLegacy (fragment {
        command_patterns."tool [a|b] [c|d] [e|f] [g|h] [i|j] [k|l]" = "allow";
      })
    );
    projectionConflictFails = fails (
      p.forLegacy (fragment {
        command."tool status" = "deny";
        command_patterns."tool status" = "allow";
      })
    );
    orderedJSONRoundTrips =
      let
        x = p.forLegacy (merged cfg);
      in
      builtins.fromJSON (p.legacyJSON "opencode" x) == x;
    openCodePrecedenceSerialization =
      p.legacyJSON "opencode" {
        agent.plan.permission.bash = {
          "*" = "deny";
          "tool *" = "deny";
          "tool status" = "allow";
        };
      }
      == ''{"agent":{"plan":{"permission":{"bash":{"*":"deny","tool *":"deny","tool status":"allow"}}}}}'';
    backendTieAgreement =
      p.legacyJSON "opencode" {
        agent.plan.permission.bash = {
          "a*b" = "deny";
          "ab*" = "allow";
        };
      } == ''{"agent":{"plan":{"permission":{"bash":{"ab*":"allow","a*b":"deny"}}}}}'';
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
          "tool [status"
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
