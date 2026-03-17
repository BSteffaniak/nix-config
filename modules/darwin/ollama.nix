{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.darwin.ollama;
in
{
  options.myConfig.darwin.ollama = {
    enable = mkEnableOption "Ollama local LLM server";
  };

  config = mkIf cfg.enable {
    # Run `ollama serve` as a persistent user-level background service.
    # Listens on all interfaces so other machines on the network can use it.
    #
    # After enabling, pull models manually:
    #   ollama pull qwen2.5:7b
    #   ollama pull qwen2.5:32b
    #
    # Models persist in ~/.ollama/models across rebuilds.
    # Allow ollama through the macOS application firewall so other
    # machines on the network can reach it.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "allowing ollama through application firewall..." >&2
      /usr/libexec/ApplicationFirewall/socketfilterfw --add ${pkgs.ollama}/bin/ollama
      /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp ${pkgs.ollama}/bin/ollama
    '';

    launchd.user.agents.ollama-serve = {
      serviceConfig = {
        Label = "com.ollama.serve";
        ProgramArguments = [
          "${pkgs.ollama}/bin/ollama"
          "serve"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/Users/${config.myConfig.username}/Library/Logs/ollama.log";
        StandardErrorPath = "/Users/${config.myConfig.username}/Library/Logs/ollama.err.log";
        EnvironmentVariables = {
          OLLAMA_HOST = "0.0.0.0:11434";
        };
      };
    };
  };
}
