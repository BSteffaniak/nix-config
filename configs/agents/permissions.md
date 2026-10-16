# Shared command permissions: compatibility lane

`permissions.schema.json` describes the shared JSON input. Nothing in this lane
opts a deployed agent into advanced mode. Upgrade the Bcode runtime **before**
adding advanced grammar or `command_policy` to enabled permission files. Do not
activate these examples on an older runtime. Nix validation does not replace the
runtime grammar parser.

## Bcode contract

Without `command_policy`, legacy command evaluation is unchanged. The generic
word DSL accepts literals, optional alternatives/groups (`[...]`), repeated
groups (`[...]*`), `<arg>`, `/regex/imsx`, `<options>*`, and trailing `...`.
Nix preserves these strings verbatim; it does not translate or parse advanced
patterns for Bcode.

Opt-in runtime contract (Nix notation):

```nix
permission.command_policy = {
  version = 1;
  layers = [
    { command = { "git *" = "deny"; }; }
    { command_patterns = { "git [--no-pager] status ..." = "allow"; }; }
  ];
};
```

Legacy `command` (including the existing `bash` alias) and `command_patterns`
remain the implicit base. For each command leaf independently, the **last
matching layer wins**; within a layer **deny > ask > allow**. An unmatched layer
does not erase an earlier decision. Layers are a list: never sorted, flattened,
deduplicated, or recursively merged. Empty policies still opt into the new mode.

`mkPermissions` composes defaults, discovered/explicit input files, then
override
files. Discovery is sorted by base filename; explicit `include` and `overrides`
lists retain caller order. Layer lists concatenate in that order. Defaults are
overridable, but conflicting identical command keys (including bash/command
aliases), word-pattern keys, or compatibility targets across user inputs and
overrides fail evaluation. Identical rules are allowed. Express intentional
command overrides as separate ordered layers, not duplicate map keys. JSON
itself
cannot safely represent duplicate keys; do not put duplicates within a file.

## OpenCode and Pi: explicit replacement, not best-effort flattening

The old finite literal/optional-single-literal projection is retained, including
`git [--no-pager] ...` and exact plus trailing-rest variants. It operates only
on literal word spellings, not shell quoting, assignments, substitutions, or
embedded scripts. This is the historical compatibility surface, **not** a proof
that raw globs and parsed shell words are equivalent for arbitrary shell text.

Precedence was inspected in the available target sources:

- `opencode-dev/packages/opencode/src/util/wildcard.ts`: ascending pattern length,
  then lexical order, with the last match winning. `tool/bash.ts` uses
  `allStructured`: command head plus an ordered tail subsequence, not exact parsed
  word matching. `?` is a wildcard as well as `*`.
- Newer `opencode/packages/core/src/permission.ts`: last matching rule in a flat
  list. Neither ordering can encode arbitrary Bcode layer decisions using a JSON
  map. Check the target version when authoring an exception.
- This repository's `configs/pi/extensions/agent-modes/index.ts`: anchored text
  globs (`*` only), exact patterns before wildcard patterns, then non-wildcard
  character count, then length. It checks split command parts. This differs from
  both OpenCode variants and from Bcode's parsed command leaves.

Advanced regex, argument captures, options, alternatives/groups, repetition, or
**any** ordered policy require explicit per-target compatibility replacements.
Absent a replacement, evaluation fails with the target/pattern and remediation;
no deny is dropped and no automatic broadened allow is generated. Conflicting
finite projections also fail rather than choosing one action.

Example **JSON input**, with deliberately stricter legacy replacements:

```json
{
  "agent": {
    "plan": {
      "permission": {
        "command_policy": {
          "version": 1,
          "layers": [
            { "command_patterns": { "tool /safe.*/i <arg>": "allow" } }
          ]
        },
        "compatibility": {
          "opencode": { "bash": { "*": "deny" } },
          "pi": { "bash": { "*": "deny" } }
        }
      }
    }
  }
}
```

`compatibility.<target>.bash` **replaces the entire final bash map**, including
base defaults and old command rules; it is not merged as exceptions. A `"*"`
default is mandatory to prevent target defaults from filling gaps with allows.
Other permission categories remain unchanged. Only the selected target's
replacement is used. Bcode receives the original command maps and ordered
layers,
with all `compatibility` metadata removed; legacy outputs contain neither
`compatibility`, `command_policy`, `command`, nor `command_patterns`.

An explicit stricter fallback (including deny-all) is supported. Authors are
responsible for reviewing any exceptions under the target's actual matching
semantics: Nix cannot prove arbitrary regex/glob policy inclusion. Do not use a
blanket allow to suppress an evaluation error. Target-specific provider configs
outside this shared generator are not governed by this translation.

## Pure evaluation tests (no activation)

From the repository root:

```sh
nix eval --impure --json --expr '
  let flake = builtins.getFlake (toString ./.);
  in import ./home/lib/tests/agent-permissions.nix { lib = flake.inputs.nixpkgs.lib; }
'
```

These evaluate directly from the working tree (new files need not be staged),
without evaluating encrypted host modules. They snapshot pre-lane output hashes,
check list composition/order, conflict handling, literal projection, advanced
string preservation, target fallbacks, and fail-closed errors. `nix flake check`
remains the broader repository check; an encrypted-host failure is not
permission
to decrypt, edit, or relocate host-private configuration.
