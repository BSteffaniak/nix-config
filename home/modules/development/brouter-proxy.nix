{
  config,
  lib,
  ...
}:

{
  options.myConfig.development.brouterProxy = {
    enable = lib.mkEnableOption "brouter-proxy provider integration (assumes you start the proxy yourself)";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host where brouter-proxy is reachable.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8581;
      description = "Port where brouter-proxy is reachable.";
    };

    providerName = lib.mkOption {
      type = lib.types.str;
      default = "brouter-proxy";
      description = "Provider key registered in pi/opencode for the proxy.";
    };

    displayName = lib.mkOption {
      type = lib.types.str;
      default = "BRouter Proxy";
      description = "Human-readable provider name shown in pi/opencode UI.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = "Default brouter-proxy model id used by Pi/OpenCode integrations.";
    };

    enablePiIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register brouter-proxy as a Pi custom provider and add a pi-brouter-proxy wrapper.";
    };

    makePiDefault = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Make brouter-proxy the default Pi provider/model. Wins over
        myConfig.development.brouter.makePiDefault when both are true.
      '';
    };

    enableOpenCodeIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register brouter-proxy as an OpenCode provider and add an opencode-brouter-proxy wrapper.";
    };

    makeOpenCodeDefault = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Make brouter-proxy the default OpenCode provider/model. Wins over
        myConfig.development.brouter.makeOpenCodeDefault when both are true.
      '';
    };
  };

  # All integration logic (pi models.json + settings.json wiring, opencode
  # provider deployment + agent overrides) lives in pi.nix and opencode.nix.
  # This module exists purely to expose the option surface so those agents'
  # config builders can read brouter-proxy settings the same way they read
  # myConfig.development.brouter.
  config = lib.mkIf config.myConfig.development.brouterProxy.enable { };
}
