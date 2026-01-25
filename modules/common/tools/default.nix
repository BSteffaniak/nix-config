{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.tools;
in
{
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
      };
    };
  };

  config = {
    environment.systemPackages =
      with pkgs;
      (optional cfg.archiving.enable _7zz)
      ++ (optional cfg.mapping.enable tippecanoe)
      ++ (optional cfg.encryption.enable age)
      ++ (optional cfg.web.enable httrack)
      ++ (optional cfg.database.postgresql.enable postgresql)
      ++ (optional cfg.ai.gemini.enable unstable.gemini-cli)
      ++ (optional cfg.ai.ollama.enable ollama);
  };
}
