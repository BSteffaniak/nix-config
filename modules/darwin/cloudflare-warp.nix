{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.cloudflareWarp;
in
{
  options.myConfig.darwin.cloudflareWarp = {
    enable = mkEnableOption "Cloudflare WARP / Zero Trust client via Homebrew";

    caCertFile = mkOption {
      type = types.str;
      default = "/Library/Application Support/cf-certs/system-ca.pem";
      description = ''
        Path to the CA bundle managed by Cloudflare WARP. This path may contain
        spaces and is therefore not passed directly to Nix builders.
      '';
    };

    nixCaCertFile = mkOption {
      type = types.str;
      default = "/etc/nix/cloudflare-warp-ca.pem";
      description = ''
        Stable, space-free symlink to caCertFile used by Nix and fixed-output
        derivations. Nixpkgs' Maven certificate importer does not quote
        NIX_SSL_CERT_FILE, so the original Cloudflare path cannot be used
        directly.
      '';
    };
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "cloudflare-warp"
    ];

    myConfig.darwin.homebrew.enable = true;

    # Keep a stable path without spaces for Nix builders. Cloudflare refreshes
    # the target bundle in place, so use a symlink rather than copying it into
    # the immutable Nix store.
    system.activationScripts.preActivation.text = lib.mkAfter ''
      echo "linking Cloudflare WARP CA bundle for Nix..." >&2
      mkdir -p "$(dirname '${cfg.nixCaCertFile}')"
      ln -sfn '${cfg.caCertFile}' '${cfg.nixCaCertFile}'
    '';

    # Make the nix-daemon trust the Cloudflare Gateway CA so substituter
    # downloads (e.g. cache.nixos.org) succeed while WARP inspects TLS.
    nix.settings.ssl-cert-file = cfg.nixCaCertFile;

    # nix.settings.ssl-cert-file only covers Nix's own HTTP client. Fixed-output
    # derivations that do their own networking (e.g. maven.buildMavenPackage,
    # which builds a Java truststore from NIX_SSL_CERT_FILE via
    # lib.fetchers.proxyImpureEnvVars) instead inherit this variable from the
    # nix-daemon's launchd environment, which nix-darwin otherwise points at
    # /etc/ssl/certs/ca-certificates.crt -- a bundle without the Gateway CA.
    # Without this, such builds fail with:
    #   "PKIX path building failed ... unable to find valid certification path".
    #
    # This is a plain string path (not a store path) on purpose: the symlink's
    # target is regenerated periodically, so it must be read at build time
    # rather than copied into the Nix store where it would go stale.
    launchd.daemons.nix-daemon.serviceConfig.EnvironmentVariables.NIX_SSL_CERT_FILE = cfg.nixCaCertFile;
  };
}
