# Read every *.json file in a directory into an attrset keyed by basename.
#
#   readJsonDir ./configs  =>  { foo = { ... }; bar = { ... }; }
dir:
let
  entries = builtins.readDir dir;
  jsonNames = builtins.filter (f: entries.${f} == "regular" && builtins.match ".*\\.json" f != null) (
    builtins.attrNames entries
  );
in
builtins.listToAttrs (
  map (f: {
    name = builtins.replaceStrings [ ".json" ] [ "" ] f;
    value = builtins.fromJSON (builtins.readFile (dir + "/${f}"));
  }) jsonNames
)
