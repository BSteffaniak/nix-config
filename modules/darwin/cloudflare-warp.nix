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
        must be told about this bundle explicitly via nix.settings, otherwise
        substituter downloads fail with:
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
  };
}
