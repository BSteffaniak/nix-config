{ lib }:

let
  inherit (lib) optionalAttrs;

  defaultThinkingLevelMap = {
    off = "none";
    minimal = "minimal";
    low = "low";
    medium = "medium";
    high = "high";
    xhigh = "max";
  };

  defaultModelDefs = [
    {
      id = "auto";
      name = "BRouter Auto";
      contextWindow = 1050000;
      maxTokens = 128000;
    }
    {
      id = "fast";
      name = "BRouter Fast";
      contextWindow = 1050000;
      maxTokens = 128000;
    }
    {
      id = "strong";
      name = "BRouter Strong";
      contextWindow = 1050000;
      maxTokens = 128000;
    }
    {
      id = "standard";
      name = "BRouter Standard";
      contextWindow = 1050000;
      maxTokens = 128000;
    }
    {
      id = "priority";
      name = "BRouter Priority";
      contextWindow = 1050000;
      maxTokens = 128000;
    }
  ];

  mkModel =
    nameSuffix: m:
    {
      inherit (m) id;
      name = m.name + nameSuffix;
      reasoning = true;
      thinkingLevelMap = defaultThinkingLevelMap;
      input = [ "text" ];
      contextWindow = m.contextWindow or 1050000;
      maxTokens = m.maxTokens or 128000;
    }
    // optionalAttrs (m ? cost) { inherit (m) cost; };
in
{
  # Pi thinking-level map shared by every brouter-shaped model. Exported so
  # callers can introspect or override per model.
  inherit defaultThinkingLevelMap defaultModelDefs;

  # Build the pi `providers.<providerName>` entry for a brouter-shaped backend.
  #
  # Args:
  #   baseUrl    : full HTTP URL including the /v1 suffix.
  #   apiKey     : API key string. brouter ignores it; "brouter" is fine.
  #   nameSuffix : optional string appended to each model display name
  #                (e.g. " (proxy)" to disambiguate brouter vs brouter-proxy).
  #   modelDefs  : override the canonical 5-model list. Each entry needs
  #                { id, name } at minimum; an optional `cost` attrset is
  #                preserved verbatim.
  mkProvider =
    {
      baseUrl,
      apiKey ? "brouter",
      nameSuffix ? "",
      modelDefs ? defaultModelDefs,
    }:
    {
      inherit baseUrl apiKey;
      api = "openai-completions";
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = true;
      };
      models = map (mkModel nameSuffix) modelDefs;
    };
}
