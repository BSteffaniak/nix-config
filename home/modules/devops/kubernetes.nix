{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.devops.kubernetes;
in
{
  options.myConfig.devops.kubernetes = {
    enable = mkEnableOption "Kubernetes tools and utilities";

    includeKind = mkOption {
      type = types.bool;
      default = true;
      description = "Include kind (Kubernetes in Docker)";
    };

    includeHelm = mkOption {
      type = types.bool;
      default = true;
      description = "Include Helm package manager";
    };

    includeK9s = mkOption {
      type = types.bool;
      default = true;
      description = "Include k9s TUI for Kubernetes";
    };

    includeStern = mkOption {
      type = types.bool;
      default = true;
      description = "Include stern for multi-pod log tailing";
    };

    includeKrew = mkOption {
      type = types.bool;
      default = true;
      description = "Include krew (kubectl plugin manager)";
    };

    includeCertManager = mkOption {
      type = types.bool;
      default = true;
      description = "Include cmctl (cert-manager CLI)";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        kubectl
      ]
      ++ (optional cfg.includeKind kind)
      ++ (optional cfg.includeHelm kubernetes-helm-wrapped)
      ++ (optional cfg.includeK9s k9s)
      ++ (optional cfg.includeStern stern)
      ++ (optional cfg.includeKrew krew)
      ++ (optional cfg.includeCertManager cmctl);

    # Shared completion hooks and aliases across all configured shells
    homeModules.shell.shared = {
      completionCommands = [ "kubectl" ];
      aliases = {
        k = "kubectl";
        kgp = "kubectl get pods";
        kgs = "kubectl get services";
        kgd = "kubectl get deployments";
        kdp = "kubectl describe pod";
        kl = "kubectl logs";
        klf = "kubectl logs -f";
      };
    };

    # XDG config for kubectl
    xdg.configFile."kubectl/.keep".text = "";

    home.sessionVariables = {
      KUBECONFIG = "$HOME/.kube/config";
    };
  };
}
