{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.devops.cloud;
in
{
  options.myConfig.devops.cloud = {
    enable = mkEnableOption "Cloud provider CLI tools";

    includeAWS = mkOption {
      type = types.bool;
      default = true;
      description = "Include AWS CLI and SAM CLI";
    };

    includeDigitalOcean = mkOption {
      type = types.bool;
      default = true;
      description = "Include doctl (DigitalOcean CLI)";
    };

    includeGCP = mkOption {
      type = types.bool;
      default = false;
      description = "Include Google Cloud SDK";
    };

    includeAzure = mkOption {
      type = types.bool;
      default = false;
      description = "Include Azure CLI";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [ ]
      ++ (optionals cfg.includeAWS [
        awscli2
        # aws-sam-cli  # TODO: broken in 25.11 - dependency version mismatches
      ])
      ++ (optional cfg.includeDigitalOcean doctl)
      ++ (optional cfg.includeGCP google-cloud-sdk)
      ++ (optional cfg.includeAzure azure-cli);

    # AWS completions
    programs.fish.interactiveShellInit = mkIf (config.programs.fish.enable && cfg.includeAWS) ''
      # AWS CLI completions
      complete -c aws -f -a '(begin; set -lx COMP_SHELL fish; set -lx COMP_LINE (commandline); aws_completer | sed \'s/ $//\'; end)'
    '';
  };
}
