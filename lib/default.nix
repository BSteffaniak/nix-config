{ lib, ... }:

{
  # Helper for enable options with a custom default value
  # Usage: mkEnableOption' cfg.enableAll "Description of the feature"
  mkEnableOption' =
    defaultValue: description:
    lib.mkOption {
      type = lib.types.bool;
      default = defaultValue;
      description = "Enable ${description}";
    };
}
