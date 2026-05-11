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
    }
    {
      id = "fast";
      name = "BRouter Fast";
    }
    {
      id = "strong";
      name = "BRouter Strong";
    }
    {
      id = "standard";
      name = "BRouter Standard";
    }
    {
      id = "priority";
      name = "BRouter Priority";
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
      contextWindow = 131072;
      maxTokens = 8192;
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
