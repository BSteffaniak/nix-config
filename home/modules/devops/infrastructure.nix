{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.devops.infrastructure;
in
{
  options.myConfig.devops.infrastructure = {
    enable = mkEnableOption "Infrastructure as Code tools";

    includeTerraform = mkOption {
      type = types.bool;
      default = true;
      description = "Include OpenTofu (Terraform fork)";
    };

    includeTerraformLS = mkOption {
      type = types.bool;
      default = true;
      description = "Include Terraform Language Server";
    };

    includeProtobuf = mkOption {
      type = types.bool;
      default = true;
      description = "Include buf (Protocol buffer tooling)";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [ ]
      ++ (optional cfg.includeTerraform opentofu)
      ++ (optional cfg.includeTerraformLS terraform-ls)
      ++ (optional cfg.includeProtobuf buf);

    # Terraform/OpenTofu aliases shared across configured shells
    homeModules.shell.shared.aliases = mkIf cfg.includeTerraform {
      tf = "tofu";
      tfi = "tofu init";
      tfp = "tofu plan";
      tfa = "tofu apply";
      tfd = "tofu destroy";
    };
  };
}
