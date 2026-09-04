{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.development.openssl;
in
{
  options.myConfig.development.openssl = {
    enable = lib.mkEnableOption "OpenSSL development environment";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      pkg-config
      openssl
      openssl.dev
    ];

    home.sessionVariables = {
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    };
  };
}
