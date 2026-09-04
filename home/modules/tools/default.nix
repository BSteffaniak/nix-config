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

let
  cfg = config.myConfig.tools;
  ollamaHost =
    let
      url = cfg.ai.ollama.serverUrl;
    in
    if lib.hasSuffix "/v1" url then lib.substring 0 (lib.stringLength url - 3) url else url;
  pullOllamaModelCommands = lib.concatMapStringsSep "\n" (model: ''
    echo "pulling ollama model ${model}..." >&2
    OLLAMA_HOST=${lib.escapeShellArg ollamaHost} ${pkgs.ollama}/bin/ollama pull ${lib.escapeShellArg model} || true
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
      enable = lib.mkEnableOption "Archive tools (7-zip)";
    };

    # Mapping/GIS tools
    mapping = {
      enable = lib.mkEnableOption "Mapping tools (tippecanoe)";
    };

    # Encryption tools
    encryption = {
      enable = lib.mkEnableOption "Encryption tools (age)";
    };

    # Web tools
    web = {
      enable = lib.mkEnableOption "Web tools (httrack website copier)";
    };

    # Database tools
    database = {
      postgresql = {
        enable = lib.mkEnableOption "PostgreSQL client tools";
      };
    };

    # AI tools
    ai = {
      gemini = {
        enable = lib.mkEnableOption "Google Gemini CLI";
      };
      ollama = {
        enable = lib.mkEnableOption "Ollama local AI runner";
        serverUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://localhost:11434/v1";
          description = "Ollama server URL (for remote hosts, use e.g. http://mac-studio:11434/v1)";
        };
        model = lib.mkOption {
          type = lib.types.str;
          default = "qwen3:14b";
          description = "Primary Ollama model ID used by local coding tools";
        };
        extraModels = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "qwen3:30b-a3b"
            "qwen2.5-coder:14b"
          ];
          description = "Additional Ollama models to register for model pickers";
        };
        modelsToPull = lib.mkOption {
          type = lib.types.listOf lib.types.str;
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
      (lib.optional cfg.archiving.enable _7zz)
      ++ (lib.optional cfg.mapping.enable tippecanoe)
      ++ (lib.optional cfg.encryption.enable age)
      ++ (lib.optional cfg.web.enable httrack)
      ++ (lib.optional cfg.database.postgresql.enable postgresql)
      ++ (lib.optional cfg.ai.gemini.enable unstable.gemini-cli)
      ++ (lib.optional cfg.ai.ollama.enable ollama);

    home.activation.pullOllamaModels = lib.mkIf (
      cfg.ai.ollama.enable && cfg.ai.ollama.modelsToPull != [ ]
    ) (lib.hm.dag.entryAfter [ "writeBoundary" ] pullOllamaModelCommands);
  };
}
