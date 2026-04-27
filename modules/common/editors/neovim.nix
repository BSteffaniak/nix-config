{ lib, ... }:

with lib;

{
  options.myConfig.editors.neovim = {
    enable = mkEnableOption "Neovim editor";

    useNightly = mkOption {
      type = types.bool;
      default = false;
      description = "Use nightly Neovim build";
    };
  };
}
