{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.devops.kubernetes;
in
{
  options.myConfig.devops.kubernetes = {
    enable = lib.mkEnableOption "Kubernetes tools and utilities";

    includeKind = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include kind (Kubernetes in Docker)";
    };

    includeHelm = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include Helm package manager";
    };

    includeK9s = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include k9s TUI for Kubernetes";
    };

    includeStern = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include stern for multi-pod log tailing";
    };

    includeKrew = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include krew (kubectl plugin manager)";
    };

    includeCertManager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include cmctl (cert-manager CLI)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        kubectl
      ]
      ++ (lib.optional cfg.includeKind kind)
      ++ (lib.optional cfg.includeHelm kubernetes-helm-wrapped)
      ++ (lib.optional cfg.includeK9s k9s)
      ++ (lib.optional cfg.includeStern stern)
      ++ (lib.optional cfg.includeKrew krew)
      ++ (lib.optional cfg.includeCertManager cmctl);

    # Shared completion hooks and aliases across all configured shells
    myConfig.shell.contrib = {
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
