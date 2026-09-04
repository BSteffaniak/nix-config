{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.containers.tools;
in
{
  options.myConfig.containers.tools = {
    enable = lib.mkEnableOption "Container debugging and management tools";

    includeDive = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include dive for exploring image layers";
    };

    includeLazydocker = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include lazydocker TUI for container management";
    };

    includeCtop = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include ctop for container monitoring";
    };

    includeSkopeo = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include skopeo for image operations";
    };

    includeBuildah = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include buildah for building OCI images";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [ ]
      ++ (lib.optional cfg.includeDive dive)
      ++ (lib.optional cfg.includeLazydocker lazydocker)
      ++ (lib.optional cfg.includeCtop ctop)
      ++ (lib.optional cfg.includeSkopeo skopeo)
      ++ (lib.optional cfg.includeBuildah buildah);
  };
}
