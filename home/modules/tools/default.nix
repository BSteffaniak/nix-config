# Tools module - shared utility tools installed via home-manager
#
# This module uses home.packages instead of environment.systemPackages
# for better portability across standalone home-manager setups (e.g., Ubuntu).
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.tools;
  ollamaHost =
    let
      url = cfg.ai.ollama.serverUrl;
    in
    if hasSuffix "/v1" url then substring 0 (stringLength url - 3) url else url;
  pullOllamaModelCommands = concatMapStringsSep "\n" (model: ''
    echo "pulling ollama model ${model}..." >&2
    OLLAMA_HOST=${escapeShellArg ollamaHost} ${pkgs.ollama}/bin/ollama pull ${escapeShellArg model} || true
  '') cfg.ai.ollama.modelsToPull;
in
{
  imports = [
    ./awake.nix
    ./tts.nix
  ];
  options.myConfig.tools = {
    # Archive tools
    archiving = {
      enable = mkEnableOption "Archive tools (7-zip)";
    };

    # Mapping/GIS tools
    mapping = {
      enable = mkEnableOption "Mapping tools (tippecanoe)";
    };

    # Encryption tools
    encryption = {
      enable = mkEnableOption "Encryption tools (age)";
    };

    # Web tools
    web = {
      enable = mkEnableOption "Web tools (httrack website copier)";
    };

    # Database tools
    database = {
      postgresql = {
        enable = mkEnableOption "PostgreSQL client tools";
      };
    };

    # AI tools
    ai = {
      gemini = {
        enable = mkEnableOption "Google Gemini CLI";
      };
      ollama = {
        enable = mkEnableOption "Ollama local AI runner";
        serverUrl = mkOption {
          type = types.str;
          default = "http://localhost:11434/v1";
          description = "Ollama server URL (for remote hosts, use e.g. http://mac-studio:11434/v1)";
        };
        model = mkOption {
          type = types.str;
          default = "qwen3:14b";
          description = "Primary Ollama model ID used by local coding tools";
        };
        extraModels = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [
            "qwen3:30b-a3b"
            "qwen2.5-coder:14b"
          ];
          description = "Additional Ollama models to register for model pickers";
        };
        modelsToPull = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [
            "qwen3:14b"
            "qwen3:30b-a3b"
          ];
          description = "Ollama models to pull during home-manager activation";
        };
      };
    };
  };

  config = {
    home.packages =
      with pkgs;
      (optional cfg.archiving.enable _7zz)
      ++ (optional cfg.mapping.enable tippecanoe)
      ++ (optional cfg.encryption.enable age)
      ++ (optional cfg.web.enable httrack)
      ++ (optional cfg.database.postgresql.enable postgresql)
      ++ (optional cfg.ai.gemini.enable unstable.gemini-cli)
      ++ (optional cfg.ai.ollama.enable ollama);

    home.activation.pullOllamaModels = mkIf (
      cfg.ai.ollama.enable && cfg.ai.ollama.modelsToPull != [ ]
    ) (lib.hm.dag.entryAfter [ "writeBoundary" ] pullOllamaModelCommands);
  };
}
