{ lib, ... }:

with lib;

{
  options.myConfig.development.openssl = {
    enable = mkEnableOption "OpenSSL development environment";
  };
}
