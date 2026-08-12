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
        Path to a CA bundle that includes the Cloudflare Gateway root
        certificate. When WARP performs TLS inspection it re-signs HTTPS
        traffic with its own root CA. The nix-daemon runs under launchd and
        does not inherit shell session variables (SSL_CERT_FILE, etc.), so it
        must be told about this bundle explicitly via both `nix.settings`
        (for Nix's own downloads) and the daemon's `NIX_SSL_CERT_FILE`
        environment variable (for fixed-output derivations that fetch over
        the network themselves), otherwise downloads fail with:
          "SSL certificate ... self-signed certificate in certificate chain".
      '';
    };
  };

  config = mkIf cfg.enable {
    homebrew.casks = [
      "cloudflare-warp"
    ];

    myConfig.darwin.homebrew.enable = true;

    # Make the nix-daemon trust the Cloudflare Gateway CA so substituter
    # downloads (e.g. cache.nixos.org) succeed while WARP inspects TLS.
    nix.settings.ssl-cert-file = cfg.caCertFile;

    # nix.settings.ssl-cert-file only covers Nix's own HTTP client. Fixed-output
    # derivations that do their own networking (e.g. maven.buildMavenPackage,
    # which builds a Java truststore from NIX_SSL_CERT_FILE via
    # lib.fetchers.proxyImpureEnvVars) instead inherit this variable from the
    # nix-daemon's launchd environment, which nix-darwin otherwise points at
    # /etc/ssl/certs/ca-certificates.crt -- a bundle without the Gateway CA.
    # Without this, such builds fail with:
    #   "PKIX path building failed ... unable to find valid certification path".
    #
    # This is a plain string path (not a store path) on purpose: the bundle is
    # regenerated periodically, so it must be read at build time rather than
    # copied into the Nix store where it would go stale.
    launchd.daemons.nix-daemon.serviceConfig.EnvironmentVariables.NIX_SSL_CERT_FILE = cfg.caCertFile;
  };
}
