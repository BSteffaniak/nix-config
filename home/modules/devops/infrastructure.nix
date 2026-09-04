{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.devops.infrastructure;
in
{
  options.myConfig.devops.infrastructure = {
    enable = lib.mkEnableOption "Infrastructure as Code tools";

    includeTerraform = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include OpenTofu (Terraform fork)";
    };

    includeTerraformLS = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include Terraform Language Server";
    };

    includeProtobuf = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include buf (Protocol buffer tooling)";
    };

    includeNats = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include natscli";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [ ]
      ++ (lib.optional cfg.includeTerraform opentofu)
      ++ (lib.optional cfg.includeTerraformLS terraform-ls)
      ++ (lib.optional cfg.includeProtobuf buf)
      ++ (lib.optional cfg.includeNats natscli);

    # Terraform/OpenTofu aliases shared across configured shells
    myConfig.shell.contrib.aliases = lib.mkIf cfg.includeTerraform {
      tf = "tofu";
      tfi = "tofu init";
      tfp = "tofu plan";
      tfa = "tofu apply";
      tfd = "tofu destroy";
    };
  };
}
