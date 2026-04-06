{ lib, ... }:

{
  defaults = {
    shell = {
      default = "nushell";
    };
  };

  # Helper for enable options with a custom default value
  # Usage: mkEnableOption' cfg.enableAll "Description of the feature"
  mkEnableOption' =
    defaultValue: description:
    lib.mkOption {
      type = lib.types.bool;
      default = defaultValue;
      description = "Enable ${description}";
    };

  # Deep merge two attrsets recursively. At every level:
  # - If both sides have an attrset for the same key, recurse and merge
  # - Otherwise, the right (override) value wins
  # Useful for composing JSON configs from a base + override files.
  deepMerge =
    let
      merge =
        lhs: rhs:
        lhs
        // builtins.mapAttrs (
          key: rhsVal:
          if builtins.hasAttr key lhs && builtins.isAttrs lhs.${key} && builtins.isAttrs rhsVal then
            merge lhs.${key} rhsVal
          else
            rhsVal
        ) rhs;
    in
    merge;
}
