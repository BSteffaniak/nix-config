# Shared command permissions

Define command policy once in `permissions/*.json`. `permissions.schema.json`
describes the input; the shared Nix generator composes defaults, discovered or
explicit files, then overrides. Discovery is sorted; explicit input order is
preserved. Conflicting identical rule keys fail rather than silently overwrite
one another. Defaults remain overridable.

## Bcode

`forBcode` preserves `command_patterns` verbatim. Upgrade the runtime before
activating advanced grammar. The runtime, not Nix, validates Rust regex syntax
and evaluates parsed operation facts.

The DSL supports literals, quoted/escaped values, optional groups and
alternatives
(`[a | b c]`), repeated groups (`[...]*`), `<arg>`, `<options>*`, whole-value
`/regex/imsx`, and trailing `...`.

`command_policy = { version = 1; layers = [...]; }` opts Bcode into ordered
layers. The implicit base is `command`/`bash` plus `command_patterns`. The last
matching layer wins, with deny > ask > allow within each layer. Layer lists
concatenate in input order, never sort or deduplicate. Legacy targets reject
ordered policies, including empty ones, rather than guess equivalent glob
precedence.

## Automatic legacy compilation

`home/lib/permission-compiler.nix` owns parsing and lowering; permission files
have no per-agent translation tables. Obsolete `compatibility` metadata is
rejected with an error. Unrelated permissions and explicit legacy `bash` rules
remain intact. Projection conflicts fail evaluation.

The compiler has bounded input/token lengths and a 256-alternative expansion
limit. It recognizes quoted/escaped literals, optional alternatives, repetition,
placeholders, regex delimiters (including escaped slashes and character
classes),
and trailing rest. Nested groups and unsupported syntax fail with rule/target
context. This is deliberately not a second shell parser or Rust regex validator.

- Finite literal alternatives expand automatically. Trailing `...` emits the
  direct command and its argument-suffix glob.
- Dynamic restrictions retain spaces around literal words and expand zero/nonzero
  argument sequences separately. An executable prefix wildcard covers common
  wrappers and paths, but literal words are not substring matches: denying `am`
  must not deny a config read of `user.name`. Options/placeholders and groups
  still conservatively overmatch rather than omit a restriction.
- A regex consisting of a plain prefix plus `.*`/`.+` retains that prefix for
  restrictions. Other regexes become a wildcard, not a dropped deny. This can
  reject additional commands; details are available in the opt-in report.
- Allows never use wildcard option prefixes or dynamic argument placeholders.
  Optional dynamic branches are omitted; repeated groups emit zero or one
  finite literal branch. These finite subsets are described in the opt-in report;
  omitted forms receive the remaining policy/default, not an automatic allow.
- Required dynamic allow values, unsafe literal shell/glob characters, unsupported
  constructs, and ordered policies fail generation. `ask` is lowered like a
  restriction, so it can conservatively prompt for additional commands.

For example, `git <options>* push ...` compiles centrally to a conservative
deny;
no Git-specific mapping exists in the compiler. A read allow with benign literal
options and `-C <arg>` branches emits direct and finite benign-option forms, but
not wildcard `-C` values.

### Opt-in translation report

Normal evaluation is quiet; unsupported/unsafe translations still throw errors.
Inspect a rule explicitly when you need translation details:

```sh
nix eval --impure --json --expr '
  let f = builtins.getFlake (toString ./.);
      compiler = import ./home/lib/permission-compiler.nix { lib = f.inputs.nixpkgs.lib; };
  in compiler.report "opencode" "git <options>* push ..." "deny"
'
```

The report returns `rules` and `diagnostics` as data, without emitting traces.
It uses the same compiler and validation as ordinary generation.

### Backend matching and serialization

Pi's actual matcher is in
`configs/pi/extensions/agent-modes/permission-rules.ts`, shared by its runtime
and behavioral tests. Pi chooses greatest literal specificity, then pattern
length; ties retain input order.

OpenCode 1.18.34 uses last-match evaluation. Use
`agentPermissions.legacyJSON "opencode" config`, not plain `builtins.toJSON`,
when emitting compiled OpenCode configurations. It orders broad defaults before
specific rules using Pi's specificity/length policy, reversing tie order so the
same first tie wins under last-match evaluation. The Home Manager module uses
this serializer for the main generated config. Provider-only files remain
outside this shared policy compilation.

The emitted literal alphabet excludes wildcard/escape syntax, so backend
escaping differences cannot turn a literal allow into a wildcard. Existing raw
`bash` patterns retain their native backend interpretation. Neither backend has
Bcode's parsed-shell authorization contract; conservative raw-glob projection
is not a general proof of argv-policy equivalence. A more-specific explicit
legacy rule can still carve out a broader restriction; test policy composition,
not just individual translations.

Normal/restricted/yolo retain distinct intent: normal build allows ordinary
push but denies destructive forms; restricted build denies push; yolo adds no
Git restrictions. Stash reads remain available; plan branch/config permissions
remain limited to read forms. Worktree-specific permissions are unchanged.

## Validation (no activation)

Pure compiler/composition tests:

```sh
nix eval --impure --json --expr '
  let f = builtins.getFlake (toString ./.);
  in import ./home/lib/tests/agent-permissions.nix { lib = f.inputs.nixpkgs.lib; }
'
```

`home/lib/tests/generated-permissions.nix` produces all three variants,
preserving
backend JSON ordering. Feed its JSON output to:

```sh
bun home/lib/tests/generated-permissions.test.ts /path/to/generated.json
```

This executes the actual Pi matcher on strings, not commands. Without
`OPENCODE_WILDCARD_MODULE`, OpenCode is explicitly reported as unchecked. To
exercise its wildcard semantics, supply that variable with a local copy of
`packages/core/src/util/wildcard.ts` from the deployed OpenCode release
(reviewed
against v1.18.34). That mode uses upstream wildcard code and last-match
resolution, not the full OpenCode agent/config loader.

The generated Bcode values can also be passed to Bcode's existing
`generated_nix_policies` integration test after normalizing `bash` to `command`.
No Nix switch, provider call, or daemon replacement is part of these checks.
`nix flake check` remains the broader repository check; encrypted-host failures
are not permission to decrypt or relocate private configuration.
